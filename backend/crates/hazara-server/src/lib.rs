//! Local friends tables. One Tokio task owns each live match.
//! The deal is written to disk before the table acknowledges a move.
//! Restarting the process restores those files. Card faces are not logged.
//!
//! # Configuration
//! HAZARA_STATE       — directory that holds store files (default: hazara-data)
//! HAZARA_BIND        — host:port to listen on (default: 127.0.0.1:8080)
//! PORT               — alternative port variable (Railway convention)
//! HAZARA_CORS_ORIGIN — comma-separated allowed origins; empty = permissive (dev only)

pub mod store;
pub mod table;
mod talk;

use std::collections::{HashMap, HashSet};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{ConnectInfo, Path, Query, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use hazara_domain::Card;
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use store::{FileStore, MatchStore, SavedGuest, SavedRoom};
use table::{parse_sets, Length, Seat, SeatStatus, Table};
use talk::Pace;
use tokio::sync::{mpsc, Mutex};
use tracing::{error, info, warn};
use uuid::Uuid;

/// Two hours in milliseconds — lobby rooms empty of players are reaped after this.
const ROOM_IDLE_TTL_MS: u64 = 2 * 60 * 60 * 1000;
/// 24 hours — orphaned match files older than this are deleted.
const MATCH_ORPHAN_TTL_MS: u64 = 24 * 60 * 60 * 1000;
/// Draft saves within this window are coalesced (a save happens on the trailing edge).
const DRAFT_DEBOUNCE_MS: u64 = 300;

#[derive(Clone)]
pub struct App {
    inner: Arc<Mutex<Lobby>>,
    store: Arc<dyn MatchStore>,
}

/// Per-IP sliding-window rate limit bucket.
struct RateBucket {
    count: u32,
    window_start: Instant,
}

impl RateBucket {
    fn fresh() -> Self {
        Self {
            count: 0,
            window_start: Instant::now(),
        }
    }
}

struct Lobby {
    guests: HashMap<String, Guest>,
    rooms: HashMap<String, Room>,
    matches: HashMap<Uuid, LiveMatch>,
    /// One-time WS upgrade tickets: ticket → (player_id, match_id, expires_at).
    ws_tickets: HashMap<Uuid, (Uuid, Uuid, Instant)>,
    /// Per-IP rate limit buckets.
    rate: HashMap<String, RateBucket>,
}

impl Lobby {
    fn new() -> Self {
        Self {
            guests: HashMap::new(),
            rooms: HashMap::new(),
            matches: HashMap::new(),
            ws_tickets: HashMap::new(),
            rate: HashMap::new(),
        }
    }

    /// Check whether the IP has exceeded `limit` requests within `window`.
    fn rate_ok(&mut self, ip: &str, limit: u32, window: Duration) -> bool {
        let bucket = self
            .rate
            .entry(ip.to_string())
            .or_insert_with(RateBucket::fresh);
        if bucket.window_start.elapsed() > window {
            *bucket = RateBucket::fresh();
        }
        bucket.count += 1;
        bucket.count <= limit
    }
}

#[derive(Clone)]
struct Guest {
    id: Uuid,
    name: String,
}

struct Room {
    code: String,
    host: Uuid,
    length: Length,
    seats: Vec<Option<Guest>>,
    match_id: Option<Uuid>,
}

struct LiveMatch {
    tx: mpsc::UnboundedSender<Cmd>,
    players: HashSet<Uuid>,
}

enum Cmd {
    Join {
        player: Uuid,
        epoch: u64,
        tx: mpsc::UnboundedSender<String>,
    },
    Leave {
        player: Uuid,
        epoch: u64,
    },
    Client {
        player: Uuid,
        text: String,
    },
    Reveal {
        gen: u64,
    },
    ClaimSeat {
        new_player: Uuid,
        new_name: String,
        reply: tokio::sync::oneshot::Sender<Result<u8, String>>,
    },
}

struct Sub {
    player: Uuid,
    epoch: u64,
    tx: mpsc::UnboundedSender<String>,
}

/// Boot the HTTP + WebSocket server. Called from the binary crate.
pub async fn run() {
    // Structured logging. Use RUST_LOG to control verbosity.
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "hazara_server=info".parse().unwrap()),
        )
        .init();

    let dir = std::env::var("HAZARA_STATE").unwrap_or_else(|_| "hazara-data".into());

    let store = match FileStore::open(&dir).await {
        Ok(s) => Arc::new(s) as Arc<dyn MatchStore>,
        Err(message) => {
            error!(error = %message, "could not open store");
            std::process::exit(1);
        }
    };

    let (guests, rooms_snapshot) = store.lobby_snapshot().await;
    let mut lobby = Lobby::new();
    for (token, guest) in &guests {
        lobby.guests.insert(
            token.clone(),
            Guest {
                id: guest.id,
                name: guest.name.clone(),
            },
        );
    }
    for (code, saved) in &rooms_snapshot {
        let length = Length::parse(&saved.length).unwrap_or(Length::Short);
        lobby.rooms.insert(
            code.clone(),
            Room {
                code: saved.code.clone(),
                host: saved.host,
                length,
                seats: saved
                    .seats
                    .iter()
                    .map(|seat| {
                        seat.as_ref().map(|person| Guest {
                            id: person.id,
                            name: person.name.clone(),
                        })
                    })
                    .collect(),
                match_id: saved.match_id,
            },
        );
    }

    let pending_matches = store.load_matches().await;
    let app = App {
        inner: Arc::new(Mutex::new(lobby)),
        store: store.clone(),
    };
    {
        let mut lobby = app.inner.lock().await;
        for (id, saved) in &pending_matches {
            let Ok(match_id) = Uuid::parse_str(id) else {
                continue;
            };
            let Ok(table) = Table::restore(saved) else {
                warn!(%match_id, "skipped unreadable match");
                continue;
            };
            spawn_match(&mut lobby, store.clone(), match_id, table);
        }
        info!(
            matches = pending_matches.len(),
            "restored matches from disk"
        );
    }

    // Bind address: HAZARA_BIND wins, then PORT (Railway), then default.
    let addr: SocketAddr = if let Ok(bind) = std::env::var("HAZARA_BIND") {
        bind.parse().unwrap_or_else(|_| {
            warn!("invalid HAZARA_BIND, using default");
            "127.0.0.1:8080".parse().unwrap()
        })
    } else if let Ok(port) = std::env::var("PORT") {
        format!("0.0.0.0:{port}")
            .parse()
            .unwrap_or_else(|_| "0.0.0.0:8080".parse().unwrap())
    } else {
        "127.0.0.1:8080".parse().unwrap()
    };

    // Periodic housekeeping — runs in the background.
    {
        let store2 = store.clone();
        let app2 = app.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(10 * 60));
            interval.tick().await; // skip the immediate first tick
            loop {
                interval.tick().await;
                let (rooms, matches) = store2.reap(ROOM_IDLE_TTL_MS, MATCH_ORPHAN_TTL_MS).await;
                if rooms > 0 || matches > 0 {
                    info!(rooms, matches, "housekeeping reaped");
                }
                // Also evict stale rate buckets and expired WS tickets.
                {
                    let mut lobby = app2.inner.lock().await;
                    lobby.rate.retain(|_, bucket| {
                        bucket.window_start.elapsed() < Duration::from_secs(120)
                    });
                    lobby
                        .ws_tickets
                        .retain(|_, (_, _, exp)| exp.elapsed() < Duration::from_secs(0));
                }
            }
        });
    }

    let router = router(app);
    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            error!(bind = %addr, error = %e, "could not bind");
            std::process::exit(1);
        }
    };
    info!(addr = %addr, store = %dir, "hazara-server ready");

    // Graceful shutdown on Ctrl-C / SIGTERM.
    let shutdown = async {
        #[cfg(unix)]
        {
            let ctrl_c = async {
                tokio::signal::ctrl_c()
                    .await
                    .expect("failed to install Ctrl-C handler");
            };
            let mut sigterm =
                tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
                    .expect("failed to install SIGTERM handler");
            tokio::select! {
                _ = ctrl_c => {}
                _ = sigterm.recv() => {}
            }
        }
        #[cfg(not(unix))]
        {
            tokio::signal::ctrl_c()
                .await
                .expect("failed to install Ctrl-C handler");
        }
        info!("shutting down");
    };

    axum::serve(
        listener,
        router.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown)
    .await
    .unwrap_or_else(|e| error!(error = %e, "serve error"));
}

fn spawn_match(lobby: &mut Lobby, store: Arc<dyn MatchStore>, match_id: Uuid, table: Table) {
    let players = table.seats.iter().map(|seat| seat.player_id).collect();
    let (tx, rx) = mpsc::unbounded_channel();
    lobby.matches.insert(
        match_id,
        LiveMatch {
            tx: tx.clone(),
            players,
        },
    );
    tokio::spawn(run_match(rx, tx, table, store, match_id));
}

async fn no_store(request: axum::extract::Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    response.headers_mut().insert(
        axum::http::header::CACHE_CONTROL,
        HeaderValue::from_static("no-store"),
    );
    response
}

fn build_cors() -> tower_http::cors::CorsLayer {
    let origins_raw = std::env::var("HAZARA_CORS_ORIGIN").unwrap_or_default();
    let trimmed: Vec<&str> = origins_raw
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    if trimmed.is_empty() {
        // Development: allow all origins.
        return tower_http::cors::CorsLayer::permissive();
    }
    use axum::http::HeaderValue;
    use tower_http::cors::AllowOrigin;
    let allowed: Vec<HeaderValue> = trimmed
        .iter()
        .filter_map(|s| s.parse::<HeaderValue>().ok())
        .collect();
    tower_http::cors::CorsLayer::new()
        .allow_origin(AllowOrigin::list(allowed))
        .allow_methods([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::OPTIONS,
        ])
        .allow_headers(tower_http::cors::Any)
}

pub fn router(app: App) -> Router {
    Router::new()
        // Liveness — returns 200 as soon as the process is up.
        .route("/healthz", get(|| async { "ok" }))
        // Readiness — returns 200 only when the store is confirmed accessible.
        .route("/readyz", get(readyz))
        // Basic Prometheus-compatible text metrics.
        .route("/metrics", get(metrics_handler))
        // API
        .route("/api/v1/guest-sessions", post(create_guest))
        .route("/api/v1/rooms", post(create_room))
        .route("/api/v1/rooms/join", post(join_room))
        .route("/api/v1/rooms/:code", get(get_room))
        .route("/api/v1/rooms/:code/preview", get(room_preview))
        .route("/api/v1/rooms/:code/start", post(start_room))
        // WS ticket — exchange player token for a one-time upgrade token.
        .route("/api/v1/matches/:id/ticket", post(match_ticket))
        // WS upgrade — accepts both token= (dev) and ticket= (prod).
        .route("/api/v1/matches/:id/ws", get(match_ws))
        .layer(middleware::from_fn(no_store))
        .layer(build_cors())
        .with_state(app)
}

async fn readyz(State(app): State<App>) -> impl IntoResponse {
    // A very basic check: can we acquire the lobby lock?
    let lobby = app.inner.lock().await;
    let matches = lobby.matches.len();
    let guests = lobby.guests.len();
    drop(lobby);
    (
        StatusCode::OK,
        Json(json!({ "status": "ready", "active_matches": matches, "guests": guests })),
    )
}

async fn metrics_handler(State(app): State<App>) -> impl IntoResponse {
    let lobby = app.inner.lock().await;
    let active_matches = lobby.matches.len();
    let guests = lobby.guests.len();
    let rooms = lobby.rooms.len();
    drop(lobby);
    let body = format!(
        "# HELP hazara_active_matches Number of live match tasks.\n\
         # TYPE hazara_active_matches gauge\n\
         hazara_active_matches {active_matches}\n\
         # HELP hazara_guests Total guest sessions created.\n\
         # TYPE hazara_guests gauge\n\
         hazara_guests {guests}\n\
         # HELP hazara_rooms Current lobby rooms.\n\
         # TYPE hazara_rooms gauge\n\
         hazara_rooms {rooms}\n"
    );
    (
        StatusCode::OK,
        [(
            axum::http::header::CONTENT_TYPE,
            "text/plain; version=0.0.4",
        )],
        body,
    )
}

struct ApiError {
    status: StatusCode,
    message: String,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(json!({ "error": self.message }))).into_response()
    }
}

fn fail(status: StatusCode, message: impl Into<String>) -> ApiError {
    ApiError {
        status,
        message: message.into(),
    }
}

#[derive(Deserialize)]
struct NameBody {
    name: String,
}

#[derive(Deserialize)]
struct CreateBody {
    match_length: String,
}

#[derive(Deserialize)]
struct JoinBody {
    code: String,
}

/// SHA-256 hex of a token string. Tokens stored on disk are hashed; the raw
/// token is returned to the client once and never stored.
fn hash_token(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    format!("{digest:x}")
}

async fn create_guest(
    State(app): State<App>,
    ConnectInfo(peer): ConnectInfo<SocketAddr>,
    Json(body): Json<NameBody>,
) -> Result<Json<Value>, ApiError> {
    // Rate limit: max 15 sign-ups per minute per IP.
    {
        let mut lobby = app.inner.lock().await;
        if !lobby.rate_ok(&peer.ip().to_string(), 15, Duration::from_secs(60)) {
            warn!(ip = %peer.ip(), "rate limited: guest-sessions");
            return Err(fail(
                StatusCode::TOO_MANY_REQUESTS,
                "Too many requests. Wait a moment.",
            ));
        }
    }
    let name = clean_name(&body.name)
        .ok_or_else(|| fail(StatusCode::BAD_REQUEST, "Enter a name of 1–16 characters."))?;
    let guest = Guest {
        id: Uuid::new_v4(),
        name,
    };
    let raw_token = Uuid::new_v4().to_string();
    let hashed = hash_token(&raw_token);
    let payload = json!({
        "token": raw_token,
        "player_id": guest.id.to_string(),
        "name": guest.name,
    });
    app.store
        .put_guest(&hashed, saved_guest(&guest))
        .await
        .map_err(|message| fail(StatusCode::INTERNAL_SERVER_ERROR, message))?;
    app.inner.lock().await.guests.insert(raw_token, guest);
    Ok(Json(payload))
}

/// Issue a one-time WS upgrade ticket.
async fn match_ticket(
    State(app): State<App>,
    headers: HeaderMap,
    Path(match_id): Path<Uuid>,
) -> Result<Json<Value>, ApiError> {
    let guest = auth(&app, &headers).await?;
    let lobby = app.inner.lock().await;
    let live = lobby
        .matches
        .get(&match_id)
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That table is not running."))?;
    if !live.players.contains(&guest.id) {
        return Err(fail(
            StatusCode::FORBIDDEN,
            "You are not seated at this table.",
        ));
    }
    let ticket = Uuid::new_v4();
    let expires = Instant::now() + Duration::from_secs(30);
    drop(lobby);
    app.inner
        .lock()
        .await
        .ws_tickets
        .insert(ticket, (guest.id, match_id, expires));
    Ok(Json(json!({ "ticket": ticket.to_string() })))
}

async fn create_room(
    State(app): State<App>,
    headers: HeaderMap,
    Json(body): Json<CreateBody>,
) -> Result<Json<Value>, ApiError> {
    let guest = auth(&app, &headers).await?;
    let length = Length::parse(&body.match_length)
        .ok_or_else(|| fail(StatusCode::BAD_REQUEST, "Choose a match length."))?;
    let mut lobby = app.inner.lock().await;
    let code = unique_code(&lobby.rooms);
    lobby.rooms.insert(
        code.clone(),
        Room {
            code: code.clone(),
            host: guest.id,
            length,
            seats: vec![Some(guest.clone()), None, None, None],
            match_id: None,
        },
    );
    let room = lobby.rooms.get(&code).unwrap();
    let saved = saved_room(room);
    let body = room_json(room, guest.id);
    drop(lobby);
    app.store
        .put_room(saved)
        .await
        .map_err(|message| fail(StatusCode::INTERNAL_SERVER_ERROR, message))?;
    Ok(Json(body))
}

async fn join_room(
    State(app): State<App>,
    headers: HeaderMap,
    Json(body): Json<JoinBody>,
) -> Result<Json<Value>, ApiError> {
    let guest = auth(&app, &headers).await?;
    let room_code = body.code.trim().to_uppercase();
    let mut lobby = app.inner.lock().await;
    let room = lobby
        .rooms
        .get_mut(&room_code)
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That code doesn't match a table."))?;
    if let Some(match_id) = room.match_id {
        let seated = room
            .seats
            .iter()
            .any(|seat| seat.as_ref().is_some_and(|person| person.id == guest.id));
        if seated {
            return Ok(Json(room_json(room, guest.id)));
        }
        let match_tx = lobby
            .matches
            .get(&match_id)
            .map(|live| live.tx.clone())
            .ok_or_else(|| fail(StatusCode::CONFLICT, "That table is not running."))?;
        let (reply_tx, reply_rx) = tokio::sync::oneshot::channel();
        match_tx
            .send(Cmd::ClaimSeat {
                new_player: guest.id,
                new_name: guest.name.clone(),
                reply: reply_tx,
            })
            .map_err(|_| fail(StatusCode::CONFLICT, "That table is not running."))?;
        drop(lobby);
        let seat = match reply_rx.await {
            Ok(Ok(seat)) => seat,
            Ok(Err(message)) => return Err(fail(StatusCode::CONFLICT, message)),
            Err(_) => return Err(fail(StatusCode::CONFLICT, "That table is not running.")),
        };

        let mut lobby = app.inner.lock().await;
        let room = lobby
            .rooms
            .get_mut(&room_code)
            .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That code doesn't match a table."))?;
        let previous = room
            .seats
            .get_mut(seat as usize)
            .and_then(|slot| slot.replace(guest.clone()));
        let saved = saved_room(room);
        let body = room_json(room, guest.id);
        if let Some(live) = lobby.matches.get_mut(&match_id) {
            if let Some(previous) = previous {
                live.players.remove(&previous.id);
            }
            live.players.insert(guest.id);
        }
        drop(lobby);
        app.store
            .put_room(saved)
            .await
            .map_err(|message| fail(StatusCode::INTERNAL_SERVER_ERROR, message))?;
        return Ok(Json(body));
    }
    if !room
        .seats
        .iter()
        .any(|seat| seat.as_ref().is_some_and(|person| person.id == guest.id))
    {
        let empty = room
            .seats
            .iter_mut()
            .find(|seat| seat.is_none())
            .ok_or_else(|| fail(StatusCode::CONFLICT, "That table is full."))?;
        *empty = Some(guest.clone());
    }
    let saved = saved_room(room);
    let body = room_json(room, guest.id);
    drop(lobby);
    app.store
        .put_room(saved)
        .await
        .map_err(|message| fail(StatusCode::INTERNAL_SERVER_ERROR, message))?;
    Ok(Json(body))
}

async fn get_room(
    State(app): State<App>,
    headers: HeaderMap,
    Path(code): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let guest = auth(&app, &headers).await?;
    let lobby = app.inner.lock().await;
    let room = lobby
        .rooms
        .get(&code.to_uppercase())
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That code doesn't match a table."))?;
    Ok(Json(room_json(room, guest.id)))
}

/// Public invite preview. Exposes no player ids or tokens.
async fn room_preview(
    State(app): State<App>,
    Path(code): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let lobby = app.inner.lock().await;
    let room = lobby
        .rooms
        .get(&code.trim().to_uppercase())
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That code doesn't match a table."))?;
    let host_name = room
        .seats
        .iter()
        .flatten()
        .find(|person| person.id == room.host)
        .map(|person| person.name.clone())
        .unwrap_or_default();
    let seats_taken = room.seats.iter().filter(|seat| seat.is_some()).count();
    Ok(Json(json!({
        "host_name": host_name,
        "seats_taken": seats_taken,
        "seats_total": 4,
        "match_length": room.length.as_str(),
        "in_progress": room.match_id.is_some(),
    })))
}

async fn start_room(
    State(app): State<App>,
    headers: HeaderMap,
    Path(code): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let guest = auth(&app, &headers).await?;
    let mut lobby = app.inner.lock().await;
    let room = lobby
        .rooms
        .get_mut(&code.to_uppercase())
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That code doesn't match a table."))?;
    if room.host != guest.id {
        return Err(fail(StatusCode::FORBIDDEN, "Only the host can start."));
    }
    if let Some(match_id) = room.match_id {
        return Ok(Json(json!({ "match_id": match_id.to_string() })));
    }
    if room.seats.iter().any(|seat| seat.is_none()) {
        return Err(fail(StatusCode::CONFLICT, "Need 4 players."));
    }
    let seats: [Seat; 4] = room
        .seats
        .iter()
        .map(|seat| {
            let person = seat.as_ref().unwrap();
            Seat {
                player_id: person.id,
                name: person.name.clone(),
                status: SeatStatus::Arranging,
            }
        })
        .collect::<Vec<_>>()
        .try_into()
        .unwrap();
    let length = room.length;
    let match_id = Uuid::new_v4();
    room.match_id = Some(match_id);
    let room_saved = saved_room(room);
    let table = Table::deal(seats, length);
    if let Err(message) = app.store.put_match(match_id, table.export()).await {
        room.match_id = None;
        return Err(fail(StatusCode::INTERNAL_SERVER_ERROR, message));
    }
    if let Err(message) = app.store.put_room(room_saved).await {
        room.match_id = None;
        return Err(fail(StatusCode::INTERNAL_SERVER_ERROR, message));
    }
    spawn_match(&mut lobby, app.store.clone(), match_id, table);
    Ok(Json(json!({ "match_id": match_id.to_string() })))
}

#[derive(Deserialize)]
struct WsQuery {
    /// Legacy: raw session token (dev only, backwards-compatible).
    token: Option<String>,
    /// Preferred: one-time ticket issued by /api/v1/matches/:id/ticket.
    ticket: Option<String>,
}

async fn match_ws(
    State(app): State<App>,
    Path(match_id): Path<Uuid>,
    Query(query): Query<WsQuery>,
    ws: WebSocketUpgrade,
) -> Result<Response, ApiError> {
    let mut lobby = app.inner.lock().await;

    let player_id: Uuid;
    if let Some(ticket_str) = &query.ticket {
        // Ticket-based auth: consume the one-time ticket.
        let ticket = ticket_str
            .parse::<Uuid>()
            .map_err(|_| fail(StatusCode::UNAUTHORIZED, "Invalid ticket."))?;
        let (pid, mid, exp) = lobby.ws_tickets.remove(&ticket).ok_or_else(|| {
            fail(
                StatusCode::UNAUTHORIZED,
                "Ticket not found or already used.",
            )
        })?;
        if exp.elapsed() > Duration::ZERO {
            return Err(fail(StatusCode::UNAUTHORIZED, "Ticket has expired."));
        }
        if mid != match_id {
            return Err(fail(
                StatusCode::FORBIDDEN,
                "Ticket is for a different match.",
            ));
        }
        player_id = pid;
    } else if let Some(token) = &query.token {
        // Legacy token-based auth (dev convenience).
        let guest = lobby
            .guests
            .get(token)
            .cloned()
            .ok_or_else(|| fail(StatusCode::UNAUTHORIZED, "Sign in with a name first."))?;
        player_id = guest.id;
    } else {
        return Err(fail(StatusCode::UNAUTHORIZED, "Provide a ticket or token."));
    }

    let live = lobby
        .matches
        .get(&match_id)
        .ok_or_else(|| fail(StatusCode::NOT_FOUND, "That table is not running."))?;
    if !live.players.contains(&player_id) {
        return Err(fail(
            StatusCode::FORBIDDEN,
            "You are not seated at this table.",
        ));
    }
    let tx = live.tx.clone();
    drop(lobby);
    Ok(ws
        .max_message_size(hazara_protocol::MAX_WS_MESSAGE_BYTES)
        .on_upgrade(move |socket| socket_loop(socket, tx, player_id)))
}

async fn socket_loop(mut socket: WebSocket, cmd_tx: mpsc::UnboundedSender<Cmd>, player: Uuid) {
    let (out_tx, mut out_rx) = mpsc::unbounded_channel();
    let epoch = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_nanos() as u64)
        .unwrap_or(0);
    if cmd_tx
        .send(Cmd::Join {
            player,
            epoch,
            tx: out_tx,
        })
        .is_err()
    {
        return;
    }
    let mut alive = tokio::time::interval(Duration::from_secs(10));
    alive.tick().await;
    loop {
        tokio::select! {
            _ = alive.tick() => {
                if socket
                    .send(Message::Text(r#"{"type":"ping"}"#.into()))
                    .await
                    .is_err()
                {
                    break;
                }
            }
            incoming = socket.recv() => {
                match incoming {
                    Some(Ok(Message::Text(text))) => {
                        let _ = cmd_tx.send(Cmd::Client { player, text: text.to_string() });
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
            outgoing = out_rx.recv() => {
                match outgoing {
                    Some(text) => {
                        if socket.send(Message::Text(text)).await.is_err() {
                            break;
                        }
                    }
                    None => break,
                }
            }
        }
    }
    let _ = cmd_tx.send(Cmd::Leave { player, epoch });
}

async fn run_match(
    mut rx: mpsc::UnboundedReceiver<Cmd>,
    tx: mpsc::UnboundedSender<Cmd>,
    mut table: Table,
    store: Arc<dyn MatchStore>,
    match_id: Uuid,
) {
    let mut reveal_armed = 0u64;
    arm_clocks(&table, &tx, &mut reveal_armed);
    let mut subs: Vec<Sub> = Vec::new();
    let mut pace: HashMap<Uuid, Pace> = HashMap::new();

    // Draft-save debouncing: when a save_draft comes in we want to wait up to
    // DRAFT_DEBOUNCE_MS before actually writing, so that rapid taps do not each
    // trigger a disk write.  We track whether a debounced save is pending.
    let mut draft_pending = false;
    let mut draft_deadline: Option<tokio::time::Instant> = None;

    loop {
        // Build a future that fires when a debounced draft save is due.
        let draft_wait = async {
            if let Some(deadline) = draft_deadline {
                tokio::time::sleep_until(deadline).await;
            } else {
                std::future::pending::<()>().await;
            }
        };

        tokio::select! {
            cmd = rx.recv() => {
                let Some(cmd) = cmd else { break };
                let mut reply: Option<(Uuid, String)> = None;
                let do_save;

                match cmd {
                    Cmd::Join { player, epoch, tx: out } => {
                        if table.seat_of(player).is_none() {
                            let _ = out.send(error_frame("You are not seated at this table."));
                            continue;
                        }
                        subs.retain(|sub| sub.player != player);
                        subs.push(Sub { player, epoch, tx: out });
                        if let Some(seat) = table.seat_of(player) {
                            table.reconnect(seat);
                        }
                        // Send current snapshot on join — do NOT save.
                        broadcast(&table, &mut subs);
                        continue;
                    }
                    Cmd::Leave { player, epoch } => {
                        subs.retain(|sub| !(sub.player == player && sub.epoch == epoch));
                        if subs.iter().any(|sub| sub.player == player) {
                            continue;
                        }
                        if let Some(seat) = table.seat_of(player) {
                            table.disconnect(seat);
                            table.pass_host_if_needed(seat);
                        }
                        do_save = true;
                    }
                    Cmd::Client { player, text } => {
                        match apply_client(&mut table, player, &text, &mut pace) {
                            Handled::Ignore => continue,
                            Handled::Direct(frame) => {
                                send_to(&subs, player, frame);
                                continue;
                            }
                            Handled::Table(frame) => {
                                for sub in &subs {
                                    let _ = sub.tx.send(frame.clone());
                                }
                                continue;
                            }
                            Handled::DraftSave => {
                                // Coalesce: reset the deadline on every draft.
                                draft_pending = true;
                                draft_deadline = Some(
                                    tokio::time::Instant::now()
                                        + Duration::from_millis(DRAFT_DEBOUNCE_MS),
                                );
                                continue;
                            }
                            Handled::Save(frame) => {
                                reply = frame.map(|frame| (player, frame));
                                do_save = true;
                            }
                        }
                    }
                    Cmd::Reveal { gen } => {
                        table.advance_reveal(gen);
                        do_save = true;
                    }
                    Cmd::ClaimSeat { new_player, new_name, reply: claim_reply } => {
                        match table.claim_vacant_seat(new_player, new_name) {
                            Ok(seat) => {
                                let _ = claim_reply.send(Ok(seat));
                                do_save = true;
                            }
                            Err(message) => {
                                let _ = claim_reply.send(Err(message));
                                continue;
                            }
                        }
                    }
                }

                if do_save {
                    draft_pending = false;
                    draft_deadline = None;
                    if store.put_match(match_id, table.export()).await.is_err() {
                        error!(%match_id, "match could not be saved");
                        if let Some((player, _)) = reply {
                            send_to(
                                &subs,
                                player,
                                error_frame("The table could not save that. Try again."),
                            );
                        }
                        continue;
                    }
                    if let Some((player, text)) = reply {
                        send_to(&subs, player, text);
                    }
                    arm_clocks(&table, &tx, &mut reveal_armed);
                    broadcast(&table, &mut subs);
                }
            }

            // Debounced draft flush.
            _ = draft_wait, if draft_pending => {
                draft_pending = false;
                draft_deadline = None;
                if store.put_match(match_id, table.export()).await.is_err() {
                    warn!(%match_id, "draft save failed");
                }
                // No broadcast needed for a draft save — no state changed visibly.
            }
        }
    }
}

fn apply_client(
    table: &mut Table,
    player: Uuid,
    text: &str,
    pace: &mut HashMap<Uuid, Pace>,
) -> Handled {
    let Some(seat) = table.seat_of(player) else {
        return Handled::Ignore;
    };
    let Ok(value) = serde_json::from_str::<Value>(text) else {
        return Handled::Ignore;
    };
    let Some(kind) = value.get("type").and_then(|item| item.as_str()) else {
        return Handled::Ignore;
    };
    let name = table.seats[seat as usize].name.clone();
    match kind {
        "ping" => Handled::Direct(json!({ "type": "pong" }).to_string()),
        "pong" => Handled::Ignore,
        "reaction" | "talk_text" | "sound" | "voice" => {
            talk_frame(player, seat, &name, kind, &value, pace)
        }
        "save_draft" => {
            let sets = match sets_from(&value) {
                Ok(sets) => sets,
                Err(message) => return Handled::Save(Some(error_frame(message))),
            };
            if let Err(message) = table.save_draft(seat, sets) {
                return Handled::Save(Some(error_frame(message)));
            }
            // Return DraftSave so the match loop debounces the disk write.
            Handled::DraftSave
        }
        "ready" => {
            let action_id = value
                .get("action_id")
                .and_then(|item| item.as_str())
                .unwrap_or("");
            if action_id.is_empty() {
                return Handled::Save(Some(error_frame("That lock could not be saved.")));
            }
            let sets = match sets_from(&value) {
                Ok(sets) => sets,
                Err(message) => return Handled::Save(Some(error_frame(message))),
            };
            match table.ready(seat, action_id, sets) {
                Ok(_) => Handled::Save(Some(
                    json!({ "type": "accepted", "action_id": action_id }).to_string(),
                )),
                Err(message) => Handled::Save(Some(error_frame(message))),
            }
        }
        "next_deal" => match table.next_deal(seat, table.summary_id) {
            Ok(()) => Handled::Save(None),
            Err(message) => Handled::Save(Some(error_frame(message))),
        },
        "rematch" => match table.rematch(seat) {
            Ok(()) => Handled::Save(None),
            Err(message) => Handled::Save(Some(error_frame(message))),
        },
        "force_end" => match table.force_end(seat) {
            Ok(()) => Handled::Save(None),
            Err(message) => Handled::Save(Some(error_frame(message))),
        },
        "nudge" => {
            // Ephemeral, never saved. Just relay to all.
            let target = value
                .get("target")
                .and_then(|item| item.as_str())
                .unwrap_or("the table");
            Handled::Table(
                serde_json::json!({
                    "type": "talk",
                    "kind": "text",
                    "from": name,
                    "text": format!("Nudges {target}!"),
                    "emojis": ["👋"],
                })
                .to_string(),
            )
        }
        _ => Handled::Save(Some(error_frame("The table did not understand that."))),
    }
}

enum Handled {
    Ignore,
    Save(Option<String>),
    DraftSave,
    Direct(String),
    Table(String),
}

fn talk_frame(
    player: Uuid,
    seat: u8,
    name: &str,
    kind: &str,
    value: &Value,
    pace: &mut HashMap<Uuid, Pace>,
) -> Handled {
    let now = table::now_ms();
    let slot = pace.entry(player).or_insert_with(Pace::fresh);
    let slow = Handled::Direct(error_frame("Give it a second."));
    match kind {
        "reaction" => {
            if !slot.allow_words(now) {
                return slow;
            }
            let emoji = value
                .get("emoji")
                .and_then(|item| item.as_str())
                .unwrap_or("");
            if !talk::is_emoji(emoji) {
                slot.words_at = 0;
                return Handled::Direct(error_frame("That reaction is not on the table."));
            }
            Handled::Table(
                json!({
                    "type": "talk",
                    "kind": "emoji",
                    "from": name,
                    "seat": seat,
                    "emoji": emoji,
                })
                .to_string(),
            )
        }
        "talk_text" => {
            if !slot.allow_words(now) {
                return slow;
            }
            let text = value
                .get("text")
                .and_then(|item| item.as_str())
                .unwrap_or("")
                .trim();
            if text.is_empty() || text.chars().count() > talk::MAX_TEXT_LEN {
                slot.words_at = 0;
                return Handled::Direct(error_frame("Keep it to a short line."));
            }
            let emojis = talk::style_text(text);
            Handled::Table(
                json!({
                    "type": "talk",
                    "kind": "text",
                    "from": name,
                    "seat": seat,
                    "text": text,
                    "emojis": emojis,
                })
                .to_string(),
            )
        }
        "sound" => {
            if !slot.allow_audio(now) {
                return slow;
            }
            let sound = value
                .get("sound")
                .and_then(|item| item.as_str())
                .unwrap_or("");
            if !talk::is_sound(sound) {
                slot.refund_audio();
                return Handled::Direct(error_frame("That sound is not on the table."));
            }
            Handled::Table(
                json!({
                    "type": "talk",
                    "kind": "sound",
                    "from": name,
                    "seat": seat,
                    "sound": sound,
                })
                .to_string(),
            )
        }
        "voice" => {
            if !slot.allow_audio(now) {
                return slow;
            }
            let mime = value
                .get("mime")
                .and_then(|item| item.as_str())
                .unwrap_or("");
            let duration_ms = value
                .get("duration_ms")
                .and_then(|item| item.as_u64())
                .unwrap_or(0);
            let audio_b64 = value
                .get("audio_b64")
                .and_then(|item| item.as_str())
                .unwrap_or("");
            if let Err(message) = talk::validate_voice(mime, duration_ms, audio_b64) {
                slot.refund_audio();
                return Handled::Direct(error_frame(message));
            }
            Handled::Table(
                json!({
                    "type": "talk",
                    "kind": "voice",
                    "from": name,
                    "seat": seat,
                    "mime": mime,
                    "duration_ms": duration_ms,
                    "audio_b64": audio_b64,
                })
                .to_string(),
            )
        }
        _ => Handled::Ignore,
    }
}

fn sets_from(value: &Value) -> Result<[Vec<Card>; 4], String> {
    let raw = value
        .get("sets")
        .and_then(|item| item.as_array())
        .ok_or_else(|| "Place all 13 cards.".to_string())?;
    let groups = raw
        .iter()
        .map(|group| {
            group
                .as_array()
                .ok_or_else(|| "Place all 13 cards.".to_string())
                .map(|cards| {
                    cards
                        .iter()
                        .filter_map(|card| card.as_str().map(str::to_string))
                        .collect::<Vec<_>>()
                })
        })
        .collect::<Result<Vec<_>, _>>()?;
    parse_sets(&groups)
}

fn send_to(subs: &[Sub], player: Uuid, text: String) {
    for sub in subs.iter().filter(|sub| sub.player == player) {
        let _ = sub.tx.send(text.clone());
    }
}

fn broadcast(table: &Table, subs: &mut Vec<Sub>) {
    subs.retain(|sub| {
        let Some(seat) = table.seat_of(sub.player) else {
            return false;
        };
        let payload = match serde_json::to_string(&json!({
            "type": "snapshot",
            "snapshot": table.snapshot(seat),
        })) {
            Ok(s) => s,
            Err(e) => {
                error!(error = %e, "snapshot serialize error");
                return false;
            }
        };
        sub.tx.send(payload).is_ok()
    });
}

fn arm_clocks(table: &Table, tx: &mpsc::UnboundedSender<Cmd>, reveal_armed: &mut u64) {
    if table.phase == table::Phase::Reveal && *reveal_armed != table.reveal_gen() {
        *reveal_armed = table.reveal_gen();
        arm_reveal(tx.clone(), table.reveal_gen(), table.reveal_until_ms());
    }
}

fn arm_reveal(tx: mpsc::UnboundedSender<Cmd>, gen: u64, until_ms: u64) {
    let wait = until_ms.saturating_sub(table::now_ms());
    tokio::spawn(async move {
        if wait > 0 {
            tokio::time::sleep(Duration::from_millis(wait)).await;
        }
        let _ = tx.send(Cmd::Reveal { gen });
    });
}

fn error_frame(message: impl Into<String>) -> String {
    json!({ "type": "error", "message": message.into() }).to_string()
}

fn saved_guest(guest: &Guest) -> SavedGuest {
    SavedGuest {
        id: guest.id,
        name: guest.name.clone(),
    }
}

fn saved_room(room: &Room) -> SavedRoom {
    SavedRoom {
        code: room.code.clone(),
        host: room.host,
        length: room.length.as_str().to_string(),
        match_id: room.match_id,
        updated_ms: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0),
        seats: room
            .seats
            .iter()
            .map(|seat| seat.as_ref().map(saved_guest))
            .collect(),
    }
}

fn room_json(room: &Room, you: Uuid) -> Value {
    let filled = room.seats.iter().filter(|seat| seat.is_some()).count();
    json!({
        "code": room.code,
        "match_length": room.length.as_str(),
        "you_are_host": room.host == you,
        "can_start": room.host == you && filled == 4 && room.match_id.is_none(),
        "match_id": room.match_id.map(|id| id.to_string()),
        "seats": room.seats.iter().enumerate().map(|(index, seat)| {
            json!({
                "seat": index,
                "name": seat.as_ref().map(|person| person.name.clone()),
                "you": seat.as_ref().is_some_and(|person| person.id == you),
            })
        }).collect::<Vec<_>>(),
    })
}

fn unique_code(rooms: &HashMap<String, Room>) -> String {
    loop {
        let code = generate_code();
        if !rooms.contains_key(&code) {
            return code;
        }
    }
}

fn generate_code() -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    use rand::Rng;
    let mut rng = rand::thread_rng();
    (0..6)
        .map(|_| {
            let index = rng.gen_range(0..ALPHABET.len());
            ALPHABET[index] as char
        })
        .collect()
}

fn clean_name(raw: &str) -> Option<String> {
    let name = raw.trim();
    let count = name.chars().count();
    if count == 0 || count > 16 {
        return None;
    }
    Some(name.to_string())
}

async fn auth(app: &App, headers: &HeaderMap) -> Result<Guest, ApiError> {
    let header = headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| fail(StatusCode::UNAUTHORIZED, "Sign in with a name first."))?;
    let token = header
        .strip_prefix("Bearer ")
        .ok_or_else(|| fail(StatusCode::UNAUTHORIZED, "Sign in with a name first."))?;
    app.inner
        .lock()
        .await
        .guests
        .get(token)
        .cloned()
        .ok_or_else(|| fail(StatusCode::UNAUTHORIZED, "Sign in with a name first."))
}

/// Bind an empty server on `127.0.0.1:0` for integration tests.
pub async fn serve_for_test(
    dir: impl AsRef<std::path::Path>,
) -> Result<SocketAddr, String> {
    let store = FileStore::open(dir).await?;
    let store: Arc<dyn MatchStore> = Arc::new(store);
    let app = App {
        inner: Arc::new(Mutex::new(Lobby::new())),
        store,
    };
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .map_err(|e| e.to_string())?;
    let addr = listener.local_addr().map_err(|e| e.to_string())?;
    let make = router(app).into_make_service_with_connect_info::<SocketAddr>();
    tokio::spawn(async move {
        let _ = axum::serve(listener, make).await;
    });
    Ok(addr)
}
