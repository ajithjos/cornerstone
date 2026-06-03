use std::env;
use std::path::PathBuf;

use anyhow::{Context, anyhow};

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub bind_address: String,
    pub database_url: String,
    pub content_root: PathBuf,
    pub bootstrap_path: PathBuf,
    pub artifacts_root: PathBuf,
    pub exports_root: PathBuf,
    pub auto_bootstrap: bool,
    pub frontend_public_url: String,
    pub developer_docs_public_url: Option<String>,
    pub dev_username_signin_enabled: bool,
    pub google_oauth_client_id: Option<String>,
    pub google_oauth_client_secret: Option<String>,
}

impl AppConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            bind_address: required_env("CORNERSTONE_BIND_ADDRESS")?,
            database_url: database_url_from_env()?,
            content_root: content_root_from_env()?,
            bootstrap_path: required_path("CORNERSTONE_BOOTSTRAP_FILE")?,
            artifacts_root: required_path("CORNERSTONE_ARTIFACTS_ROOT")?,
            exports_root: required_path("CORNERSTONE_EXPORTS_ROOT")?,
            auto_bootstrap: required_bool("CORNERSTONE_AUTO_BOOTSTRAP")?,
            frontend_public_url: required_env("CORNERSTONE_FRONTEND_PUBLIC_URL")?,
            developer_docs_public_url: optional_env("CORNERSTONE_DEVELOPER_DOCS_URL"),
            dev_username_signin_enabled: optional_bool("CORNERSTONE_DEV_USERNAME_SIGNIN_ENABLED", false)?,
            google_oauth_client_id: optional_env("CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID"),
            google_oauth_client_secret: optional_env("CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET"),
        })
    }
}

pub fn database_url_from_env() -> anyhow::Result<String> {
    required_env("CORNERSTONE_DATABASE_URL")
}

pub fn content_root_from_env() -> anyhow::Result<PathBuf> {
    required_path("CORNERSTONE_CONTENT_ROOT")
}

fn required_env(key: &str) -> anyhow::Result<String> {
    let value = env::var(key).with_context(|| format!("{key} must be set"))?;
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(anyhow!("{key} cannot be empty"));
    }
    Ok(trimmed.to_string())
}

fn optional_env(key: &str) -> Option<String> {
    env::var(key).ok().and_then(|value| {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    })
}

fn required_path(key: &str) -> anyhow::Result<PathBuf> {
    let raw = required_env(key)?;
    let path = PathBuf::from(raw);
    if path.as_os_str().is_empty() {
        return Err(anyhow!("{key} cannot resolve to an empty path"));
    }
    Ok(path)
}

fn required_bool(key: &str) -> anyhow::Result<bool> {
    parse_bool(&required_env(key)?)
}

fn optional_bool(key: &str, default: bool) -> anyhow::Result<bool> {
    match env::var(key) {
        Ok(value) => parse_bool(&value),
        Err(env::VarError::NotPresent) => Ok(default),
        Err(env::VarError::NotUnicode(_)) => Err(anyhow!("{key} must be valid UTF-8")),
    }
}

fn parse_bool(value: &str) -> anyhow::Result<bool> {
    match value.trim().to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" => Ok(true),
        "0" | "false" | "no" | "off" => Ok(false),
        _ => Err(anyhow!("cannot parse boolean value '{value}'")),
    }
}
