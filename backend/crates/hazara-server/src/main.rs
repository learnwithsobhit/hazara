//! HAZARA table server binary.

#[tokio::main]
async fn main() {
    hazara_server::run().await;
}
