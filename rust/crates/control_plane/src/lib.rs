mod config;
mod domain;
mod http;
mod service;

use std::sync::Arc;

use anyhow::Context;
use clap::{Parser, Subcommand};
use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

pub use config::AppConfig;

#[derive(Debug, Parser)]
#[command(name = "control_plane")]
#[command(about = "Cornerstone MVP control plane")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Server,
    Migrate,
    BootstrapApply,
    LibraryValidate,
}

pub async fn run_cli() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with_target(false)
        .compact()
        .init();

    let cli = Cli::parse();

    match cli.command {
        Command::Server => run_server(AppConfig::from_env()?).await,
        Command::Migrate => {
            let database_url = config::database_url_from_env()?;
            service::migrate_database(&database_url).await
        }
        Command::BootstrapApply => {
            let state = service::initialize_state(AppConfig::from_env()?, false).await?;
            let result = service::apply_bootstrap(&state).await?;
            println!("{}", serde_json::to_string_pretty(&result)?);
            Ok(())
        }
        Command::LibraryValidate => {
            let content_root = config::content_root_from_env()?;
            let (bundle, report) = catalog::load_library_bundle(&content_root)?;
            service::validate_supported_material_runtimes(&bundle)?;
            println!("{}", serde_json::to_string_pretty(&report)?);
            println!(
                "Loaded {} subjects, {} areas, {} pathways, {} skills, {} stages, {} playlists, {} materials",
                bundle.subjects.len(),
                bundle.areas.len(),
                bundle.pathways.len(),
                bundle.skills.len(),
                bundle.stages.len(),
                bundle.playlists.len(),
                bundle.materials.len()
            );
            Ok(())
        }
    }
}

async fn run_server(config: AppConfig) -> anyhow::Result<()> {
    let state = service::initialize_state(config.clone(), true).await?;
    let router = http::router(Arc::clone(&state));
    let listener = TcpListener::bind(&config.bind_address)
        .await
        .with_context(|| format!("failed to bind {}", config.bind_address))?;
    tracing::info!("Cornerstone control plane listening on {}", config.bind_address);
    axum::serve(listener, router)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .context("HTTP server failed")
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}
