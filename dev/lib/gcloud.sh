#!/usr/bin/env bash

dev_gcloud_print_setup_hint() {
	local prefix="${1:-dev/gcloud}"
	local gcloud_bin="${GCLOUD_BIN:-gcloud}"

	echo "[$prefix] Expected local gcloud setup:" >&2
	echo "  $gcloud_bin auth login ${GCP_ACCOUNT:-<account>}" >&2
	echo "  $gcloud_bin config configurations create $GCP_CONFIG_NAME || true" >&2
	echo "  $gcloud_bin config configurations activate $GCP_CONFIG_NAME" >&2
	if [[ -n "${GCP_ACCOUNT:-}" ]]; then
		echo "  $gcloud_bin config set account $GCP_ACCOUNT" >&2
	else
		echo "  $gcloud_bin config set account <account>" >&2
	fi
	echo "  $gcloud_bin config set project $GCP_PROJECT_ID" >&2
	if [[ -n "${GCP_ZONE:-}" ]]; then
		echo "  $gcloud_bin config set compute/zone $GCP_ZONE" >&2
	fi
}

dev_gcloud_check_context() {
	local prefix="${1:-dev/gcloud}"
	local gcloud_bin="${GCLOUD_BIN:-gcloud}"
	local active_account
	local active_config
	local current_project

	command -v "$gcloud_bin" >/dev/null 2>&1 || {
		echo "[$prefix] ERROR: required command not found: $gcloud_bin" >&2
		exit 10
	}

	active_config="$("$gcloud_bin" config configurations list --filter=is_active:true --format='value(name)' 2>/dev/null | head -n 1 || true)"
	current_project="$("$gcloud_bin" config get-value project 2>/dev/null | tr -d '\n' || true)"
	active_account="$("$gcloud_bin" auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1 || true)"

	if [[ "$active_config" != "$GCP_CONFIG_NAME" ]]; then
		echo "[$prefix] ERROR: active gcloud config is '${active_config:-<none>}', expected '$GCP_CONFIG_NAME'." >&2
		dev_gcloud_print_setup_hint "$prefix"
		exit 3
	fi

	if [[ "$current_project" != "$GCP_PROJECT_ID" ]]; then
		echo "[$prefix] ERROR: active gcloud project is '${current_project:-<none>}', expected '$GCP_PROJECT_ID'." >&2
		dev_gcloud_print_setup_hint "$prefix"
		exit 4
	fi

	if [[ -n "${GCP_ACCOUNT:-}" && "$active_account" != "$GCP_ACCOUNT" ]]; then
		echo "[$prefix] ERROR: active gcloud account is '${active_account:-<none>}', expected '$GCP_ACCOUNT'." >&2
		dev_gcloud_print_setup_hint "$prefix"
		exit 4
	fi

	if [[ -n "${GCP_ACCOUNT:-}" ]]; then
		if ! "$gcloud_bin" auth print-access-token --account "$GCP_ACCOUNT" >/dev/null 2>&1; then
			echo "[$prefix] ERROR: gcloud authentication for '$GCP_ACCOUNT' is not usable." >&2
			dev_gcloud_print_setup_hint "$prefix"
			exit 4
		fi
	elif ! "$gcloud_bin" auth print-access-token >/dev/null 2>&1; then
		echo "[$prefix] ERROR: active gcloud authentication is not usable." >&2
		dev_gcloud_print_setup_hint "$prefix"
		exit 4
	fi
}
