//! Versioned activity assets are read from content, never compiled into Flutter or Rust.
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Component, Path};

use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageDescriptor {
    pub package_id: String,
    pub version: String,
    pub entry_url: String,
    pub protocol_version: u16,
    pub integrity: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Registry {
    packages: Vec<RegistryEntry>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct RegistryEntry {
    package_id: String,
    version: String,
    path: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Manifest {
    package_id: String,
    version: String,
    protocol_version: u16,
    entry: String,
    files: Vec<String>,
    sha256: BTreeMap<String, String>,
}

pub struct PackageAsset {
    pub bytes: Vec<u8>,
    pub content_type: &'static str,
}

struct ValidatedPackage {
    descriptor: PackageDescriptor,
    files: BTreeMap<String, Vec<u8>>,
}

pub const NUMERIC_VERSION: &str = "1.1.0";

pub fn resolve_package(content_root: &Path, package_id: &str, version: &str) -> Result<PackageDescriptor> {
    Ok(load_package(content_root, package_id, version)?.descriptor)
}

pub fn validate_library_packages(content_root: &Path, bundle: &catalog::LibraryBundle) -> Result<()> {
    let registry_path = content_root.join("activity_packages/registry.json");
    let registry: Registry = serde_json::from_slice(&read_bounded(&registry_path, 262_144)?)?;
    let mut registered = BTreeSet::new();
    for entry in &registry.packages {
        resolve_package(content_root, &entry.package_id, &entry.version)?;
        registered.insert((entry.package_id.clone(), entry.version.clone()));
    }
    for material in &bundle.materials {
        let Some(runtime) = &material.runtime else { continue };
        let identity = runtime
            .presentation
            .as_ref()
            .map(|presentation| (presentation.package_id.clone(), presentation.version.clone()))
            .unwrap_or_else(|| ("numeric-questions".to_owned(), NUMERIC_VERSION.to_owned()));
        ensure!(
            registered.contains(&identity),
            "material {} references an unregistered activity package",
            material.id
        );
    }
    Ok(())
}

pub fn load_asset(
    content_root: &Path,
    package_id: &str,
    version: &str,
    asset_path: &str,
    integrity: Option<&str>,
) -> Result<PackageAsset> {
    validate_relative_path(asset_path)?;
    let mut package = load_package(content_root, package_id, version)?;
    if let Some(expected) = integrity {
        ensure!(
            expected == package.descriptor.integrity,
            "activity package changed; the assigned version must be restored"
        );
    }
    let bytes = package
        .files
        .remove(asset_path)
        .context("asset is not declared by the activity package")?;
    Ok(PackageAsset {
        bytes,
        content_type: content_type(asset_path)?,
    })
}

fn read_bounded(path: &Path, limit: u64) -> Result<Vec<u8>> {
    let size = std::fs::metadata(path)
        .with_context(|| format!("cannot read {}", path.display()))?
        .len();
    ensure!(size <= limit, "activity package file is too large");
    let bytes = std::fs::read(path)?;
    ensure!(bytes.len() as u64 <= limit, "activity package file is too large");
    Ok(bytes)
}

fn load_package(content_root: &Path, package_id: &str, version: &str) -> Result<ValidatedPackage> {
    ensure!(
        valid_identifier(package_id) && valid_identifier(version),
        "invalid activity package identity"
    );
    let root = content_root
        .join("activity_packages")
        .canonicalize()
        .context("activity package directory is unavailable")?;
    let registry: Registry = serde_json::from_slice(&read_bounded(&root.join("registry.json"), 262_144)?)?;
    let mut identities = BTreeSet::new();
    for item in &registry.packages {
        ensure!(
            identities.insert((&item.package_id, &item.version)),
            "duplicate activity package registration"
        );
    }
    let registered = registry
        .packages
        .iter()
        .find(|item| item.package_id == package_id && item.version == version)
        .context("activity package version is not registered")?;
    validate_relative_path(&registered.path)?;
    let directory = root.join(&registered.path).canonicalize()?;
    ensure!(
        directory.starts_with(&root),
        "activity package path leaves the package directory"
    );
    let manifest_path = directory.join("manifest.json").canonicalize()?;
    ensure!(
        manifest_path.starts_with(&directory),
        "activity manifest leaves the package directory"
    );
    let manifest_bytes = read_bounded(&manifest_path, 131_072)?;
    let manifest: Manifest = serde_json::from_slice(&manifest_bytes)?;
    ensure!(
        manifest.package_id == package_id && manifest.version == version,
        "activity manifest identity does not match registration"
    );
    ensure!(manifest.protocol_version == 1, "unsupported activity package protocol");
    ensure!(
        !manifest.files.is_empty() && manifest.files.len() <= 64,
        "activity package must declare 1–64 assets"
    );
    ensure!(
        manifest.entry.ends_with(".html") && manifest.files.contains(&manifest.entry),
        "activity entry must be a declared HTML asset"
    );
    let mut files = BTreeMap::new();
    let mut total_size = 0;
    for name in &manifest.files {
        validate_relative_path(name)?;
        content_type(name)?;
        ensure!(!files.contains_key(name), "duplicate activity asset");
        let path = directory.join(name).canonicalize()?;
        ensure!(
            path.starts_with(&directory),
            "activity asset leaves the package directory"
        );
        let bytes = read_bounded(&path, 5_242_880)?;
        total_size += bytes.len();
        ensure!(total_size <= 20_971_520, "activity package exceeds 20 MiB");
        let digest = format!("{:x}", Sha256::digest(&bytes));
        ensure!(
            manifest.sha256.get(name) == Some(&digest),
            "activity asset checksum mismatch: {name}"
        );
        files.insert(name.clone(), bytes);
    }
    ensure!(
        manifest.sha256.len() == files.len(),
        "checksum list must exactly match declared activity assets"
    );
    let integrity = format!("{:x}", Sha256::digest(&manifest_bytes));
    Ok(ValidatedPackage {
        descriptor: PackageDescriptor {
            package_id: package_id.into(),
            version: version.into(),
            entry_url: format!(
                "/api/v1/activity-packages/{package_id}/{version}/{}?integrity={integrity}",
                manifest.entry
            ),
            protocol_version: manifest.protocol_version,
            integrity,
        },
        files,
    })
}

fn valid_identifier(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 80
        && value != "."
        && value != ".."
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.'))
}

fn validate_relative_path(value: &str) -> Result<()> {
    ensure!(!value.is_empty() && value.len() <= 240, "invalid activity asset path");
    ensure!(
        value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'/')),
        "invalid activity asset path"
    );
    ensure!(
        Path::new(value)
            .components()
            .all(|part| matches!(part, Component::Normal(_))),
        "activity asset path must stay inside its package"
    );
    ensure!(
        !value
            .split('/')
            .any(|part| part.is_empty() || part == "." || part == ".."),
        "invalid activity asset path"
    );
    Ok(())
}

fn content_type(name: &str) -> Result<&'static str> {
    match Path::new(name).extension().and_then(|extension| extension.to_str()) {
        Some("html") => Ok("text/html; charset=utf-8"),
        Some("js") => Ok("text/javascript; charset=utf-8"),
        Some("css") => Ok("text/css; charset=utf-8"),
        Some("json") => Ok("application/json; charset=utf-8"),
        Some("svg") => Ok("image/svg+xml"),
        Some("png") => Ok("image/png"),
        Some("jpg" | "jpeg") => Ok("image/jpeg"),
        Some("woff2") => Ok("font/woff2"),
        _ => bail!("unsupported activity asset type"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> std::path::PathBuf {
        let root = std::env::temp_dir().join(format!("cornerstone-packages-{}", uuid::Uuid::new_v4()));
        let package = root.join("activity_packages/example/1.0.0");
        std::fs::create_dir_all(&package).unwrap();
        std::fs::write(
            root.join("activity_packages/registry.json"),
            r#"{"packages":[{"package_id":"example","version":"1.0.0","path":"example/1.0.0"}]}"#,
        )
        .unwrap();
        let html = b"<!doctype html><title>Example activity</title>";
        std::fs::write(package.join("index.html"), html).unwrap();
        std::fs::write(package.join("manifest.json"), serde_json::to_vec(&serde_json::json!({
            "package_id":"example", "version":"1.0.0", "protocol_version":1,
            "entry":"index.html", "files":["index.html"], "sha256":{"index.html":format!("{:x}",Sha256::digest(html))}
        })).unwrap()).unwrap();
        root
    }

    #[test]
    fn registered_assets_are_loaded_from_content_and_pinned_to_manifest() {
        let root = fixture();
        let descriptor = resolve_package(&root, "example", "1.0.0").unwrap();
        assert!(descriptor.entry_url.contains(&descriptor.integrity));
        assert!(load_asset(&root, "example", "1.0.0", "index.html", Some(&descriptor.integrity)).is_ok());
        assert!(load_asset(&root, "example", "1.0.0", "index.html", Some("old-manifest")).is_err());
        assert!(load_asset(&root, "example", "1.0.0", "manifest.json", None).is_err());
        std::fs::write(
            root.join("activity_packages/example/1.0.0/index.html"),
            "changed after publication",
        )
        .unwrap();
        assert!(resolve_package(&root, "example", "1.0.0").is_err());
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn path_traversal_and_unregistered_versions_are_rejected() {
        let root = fixture();
        for path in [
            "../registry.json",
            "/index.html",
            "a/../../index.html",
            "a\\index.html",
            "./index.html",
        ] {
            assert!(load_asset(&root, "example", "1.0.0", path, None).is_err(), "{path}");
        }
        assert!(resolve_package(&root, "example", "2.0.0").is_err());
        std::fs::remove_dir_all(root).unwrap();
    }
}
