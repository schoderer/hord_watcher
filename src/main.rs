use std::net::SocketAddr;

use axum::{http::StatusCode, response::IntoResponse, routing::get, Router};

use crate::events::{watch_kubernetes_events, WatchedNamespaces};

mod app_config;
mod events;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::SubscriberBuilder::default()
        .json()
        .init();
    let config = app_config::load_config()?;

    let observed_namespaces = match config.namespaces {
        Some(namespaces) => WatchedNamespaces::Selected(namespaces),
        None => WatchedNamespaces::All,
    };
    tracing::info!("Watching namespaces: {:?}", observed_namespaces);

    tokio::select! {
        _ = start_server(config.port) => tracing::error!("Server terminated"),
        _ = watch_kubernetes_events(observed_namespaces) => tracing::error!("Event-Watcher terminated"),
    }
    Ok(())
}

async fn start_server(port: u16) {
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("listening on {}", addr);

    let app = Router::new().route("/health", get(health_check));

    let server = axum::Server::bind(&addr).serve(app.into_make_service());
    if let Err(err) = server.await {
        tracing::error!("Shutting server down due to error: {err}");
    }
}
async fn health_check() -> impl IntoResponse {
    (StatusCode::OK, "")
}
