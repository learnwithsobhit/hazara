//! Four-client WebSocket integration: deal, reconnect, full ready lock.

use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use hazara_engine::deterministic_legal;
use hazara_server::table::parse_card;
use serde_json::{json, Value};
use tokio_tungstenite::tungstenite::Message;
use uuid::Uuid;

async fn post_json(base: &str, path: &str, token: Option<&str>, body: Value) -> Value {
    let mut req = reqwest::Client::new()
        .post(format!("{base}{path}"))
        .json(&body);
    if let Some(token) = token {
        req = req.header("Authorization", format!("Bearer {token}"));
    }
    req.send()
        .await
        .unwrap()
        .error_for_status()
        .unwrap()
        .json()
        .await
        .unwrap()
}

async fn get_json(base: &str, path: &str, token: Option<&str>) -> reqwest::Response {
    let mut req = reqwest::Client::new().get(format!("{base}{path}"));
    if let Some(token) = token {
        req = req.header("Authorization", format!("Bearer {token}"));
    }
    req.send().await.unwrap()
}

async fn guest(base: &str, name: &str) -> String {
    let body = post_json(base, "/api/v1/guest-sessions", None, json!({ "name": name })).await;
    body["token"].as_str().unwrap().to_string()
}

async fn connect_ws(
    base_http: &str,
    match_id: &str,
    token: &str,
) -> tokio_tungstenite::WebSocketStream<
    tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
> {
    let ticket = post_json(
        base_http,
        &format!("/api/v1/matches/{match_id}/ticket"),
        Some(token),
        json!({}),
    )
    .await;
    let ticket = ticket["ticket"].as_str().expect("ticket");
    let ws_url = base_http
        .replacen("http://", "ws://", 1)
        + &format!("/api/v1/matches/{match_id}/ws?ticket={ticket}");
    let (ws, _) = tokio_tungstenite::connect_async(ws_url).await.unwrap();
    ws
}

async fn wait_snapshot(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
) -> Value {
    let deadline = tokio::time::Instant::now() + Duration::from_secs(8);
    loop {
        let frame = tokio::time::timeout_at(deadline, ws.next())
            .await
            .expect("snapshot timeout")
            .expect("ws closed")
            .unwrap();
        let Message::Text(text) = frame else { continue };
        let v: Value = serde_json::from_str(&text).unwrap();
        if v["type"] == "snapshot" {
            return v["snapshot"].clone();
        }
    }
}

#[tokio::test]
async fn four_clients_deal_reconnect_and_lock() {
    let dir = std::env::temp_dir().join(format!("hazara-ws-{}", Uuid::new_v4()));
    tokio::fs::create_dir_all(&dir).await.unwrap();
    let addr = hazara_server::serve_for_test(&dir).await.unwrap();
    let base = format!("http://{addr}");

    let names = ["Ada", "Bo", "Cy", "Di"];
    let tokens: Vec<String> = {
        let mut out = Vec::new();
        for name in names {
            out.push(guest(&base, name).await);
        }
        out
    };

    let created = post_json(
        &base,
        "/api/v1/rooms",
        Some(&tokens[0]),
        json!({ "match_length": "one_deal" }),
    )
    .await;
    let code = created["code"].as_str().unwrap().to_string();

    let preview = get_json(&base, &format!("/api/v1/rooms/{code}/preview"), None)
        .await
        .json::<Value>()
        .await
        .unwrap();
    assert_eq!(preview["host_name"], "Ada");
    assert_eq!(preview["seats_taken"], 1);
    assert_eq!(preview["in_progress"], false);

    for token in tokens.iter().skip(1) {
        post_json(
            &base,
            "/api/v1/rooms/join",
            Some(token),
            json!({ "code": code }),
        )
        .await;
    }

    let started = post_json(
        &base,
        &format!("/api/v1/rooms/{code}/start"),
        Some(&tokens[0]),
        json!({}),
    )
    .await;
    let match_id = started["match_id"].as_str().unwrap().to_string();

    let mut sockets = Vec::new();
    let mut hands: Vec<Vec<String>> = Vec::new();
    for token in &tokens {
        let mut ws = connect_ws(&base, &match_id, token).await;
        let snap = wait_snapshot(&mut ws).await;
        assert_eq!(snap["protocol"], 1);
        assert_eq!(snap["phase"], "arranging");
        let hand: Vec<String> = snap["hand"]
            .as_array()
            .unwrap()
            .iter()
            .map(|id| id.as_str().unwrap().to_string())
            .collect();
        assert_eq!(hand.len(), 13);
        hands.push(hand);
        sockets.push(ws);
    }

    // Reconnect seat 2 with a fresh ticket; the hole must survive.
    {
        let old = std::mem::replace(
            &mut sockets[2],
            connect_ws(&base, &match_id, &tokens[2]).await,
        );
        drop(old);
        let snap = wait_snapshot(&mut sockets[2]).await;
        assert_eq!(snap["hand"].as_array().unwrap().len(), 13);
    }

    for (i, ws) in sockets.iter_mut().enumerate() {
        let cards: Vec<_> = hands[i]
            .iter()
            .filter_map(|id| parse_card(id))
            .collect();
        let sets = deterministic_legal(&cards).expect("legal hand");
        let payload = json!({
            "type": "ready",
            "action_id": format!("lock-{i}"),
            "sets": sets
                .iter()
                .map(|group| group.iter().map(|c| c.id()).collect::<Vec<_>>())
                .collect::<Vec<_>>(),
        });
        ws.send(Message::Text(payload.to_string().into()))
            .await
            .unwrap();
    }

    let mut saw_reveal = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(8);
    while tokio::time::Instant::now() < deadline {
        let frame = tokio::time::timeout_at(deadline, sockets[0].next())
            .await
            .ok()
            .flatten();
        let Some(Ok(Message::Text(text))) = frame else {
            continue;
        };
        let v: Value = serde_json::from_str(&text).unwrap();
        if v["type"] == "snapshot" && v["snapshot"]["phase"] == "reveal" {
            saw_reveal = true;
            assert!(!v["snapshot"]["beats"].as_array().unwrap().is_empty());
            break;
        }
    }
    assert!(saw_reveal, "table never reached reveal");

    let preview = get_json(&base, &format!("/api/v1/rooms/{code}/preview"), None)
        .await
        .json::<Value>()
        .await
        .unwrap();
    assert_eq!(preview["seats_taken"], 4);
    assert_eq!(preview["in_progress"], true);

    let _ = tokio::fs::remove_dir_all(&dir).await;
}
