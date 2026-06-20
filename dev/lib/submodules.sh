#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: submodules.sh <sync|check> [--repo-root <path>] [--remote <name>]

sync  Initialize root submodules, switch them to their configured branch
      (default: master), and rebase local work on top of the remote branch.
check Verify root submodules are initialized, clean, on their configured branch,
      and at or ahead of the remote branch.

Repositories without .gitmodules pass both modes as a no-op.
EOF
}

MODE="${1:-}"
if [[ "$MODE" == "sync" || "$MODE" == "check" ]]; then
	shift
else
	usage >&2
	exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$DEFAULT_REPO_ROOT"
REMOTE="origin"

while (($# > 0)); do
	case "$1" in
		--repo-root)
			[[ $# -ge 2 ]] || {
				echo "--repo-root requires a value" >&2
				exit 2
			}
			REPO_ROOT="$2"
			shift 2
			;;
		--remote)
			[[ $# -ge 2 ]] || {
				echo "--remote requires a value" >&2
				exit 2
			}
			REMOTE="$2"
			shift 2
			;;
		-h | --help | help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
	esac
done

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
cd "$REPO_ROOT"

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
	echo "[submodules] $REPO_ROOT is not a git worktree" >&2
	exit 1
fi

if [[ ! -f .gitmodules ]]; then
	echo "[submodules] No .gitmodules found; no submodules to ${MODE}."
	exit 0
fi

declare -a SUBMODULE_NAMES=()
declare -a SUBMODULE_PATHS=()
declare -a SUBMODULE_BRANCHES=()

while read -r key path; do
	name="${key#submodule.}"
	name="${name%.path}"
	branch="$(git config -f .gitmodules "submodule.${name}.branch" || true)"
	branch="${branch:-master}"
	SUBMODULE_NAMES+=("$name")
	SUBMODULE_PATHS+=("$path")
	SUBMODULE_BRANCHES+=("$branch")
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' || true)

if ((${#SUBMODULE_PATHS[@]} == 0)); then
	echo "[submodules] .gitmodules has no root submodule paths; no submodules to ${MODE}."
	exit 0
fi

timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"

sync_one() {
	local path="$1"
	local branch="$2"
	local repo="$REPO_ROOT/$path"
	local remote_ref="refs/remotes/$REMOTE/$branch"

	echo "[submodules] $path: fetching $REMOTE/$branch"
	git -C "$repo" fetch "$REMOTE" --prune

	if ! git -C "$repo" show-ref --verify --quiet "$remote_ref"; then
		echo "[submodules] $path: missing $REMOTE/$branch" >&2
		return 1
	fi

	local remote_head current_head current_branch dirty
	local backup_head_ref=""
	local backup_branch_ref=""
	local stash_needed=0
	local branch_head=""

	remote_head="$(git -C "$repo" rev-parse "$REMOTE/$branch")"
	current_head="$(git -C "$repo" rev-parse HEAD)"
	current_branch="$(git -C "$repo" symbolic-ref --short -q HEAD || true)"
	dirty="$(git -C "$repo" status --porcelain --untracked-files=all)"

	if [[ "$current_head" != "$remote_head" || -n "$dirty" ]]; then
		backup_head_ref="backup/submodule-sync-$timestamp"
		git -C "$repo" branch "$backup_head_ref" "$current_head" >/dev/null 2>&1 || true
	fi

	if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
		branch_head="$(git -C "$repo" rev-parse "refs/heads/$branch")"
		if [[ "$branch_head" != "$current_head" && "$branch_head" != "$remote_head" ]]; then
			backup_branch_ref="backup/${branch//\//-}-before-sync-$timestamp"
			git -C "$repo" branch "$backup_branch_ref" "$branch_head" >/dev/null 2>&1 || true
		fi
	fi

	if [[ -n "$dirty" ]]; then
		stash_needed=1
		echo "[submodules] $path: stashing local changes"
		git -C "$repo" stash push --include-untracked --message "submodule-sync-$timestamp" >/dev/null
	fi

	if [[ "$current_branch" == "$branch" ]]; then
		git -C "$repo" branch --set-upstream-to="$REMOTE/$branch" "$branch" >/dev/null 2>&1 || true
		git -C "$repo" rebase "$REMOTE/$branch"
	else
		if [[ -n "$backup_head_ref" ]]; then
			git -C "$repo" switch -C "$branch" "$backup_head_ref" >/dev/null
		elif git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
			git -C "$repo" switch "$branch" >/dev/null
		else
			git -C "$repo" switch --track -c "$branch" "$REMOTE/$branch" >/dev/null
		fi

		git -C "$repo" branch --set-upstream-to="$REMOTE/$branch" "$branch" >/dev/null

		if [[ "$(git -C "$repo" rev-parse HEAD)" != "$remote_head" || -n "$backup_head_ref" ]]; then
			git -C "$repo" rebase "$REMOTE/$branch"
		fi
	fi

	if ((stash_needed)); then
		echo "[submodules] $path: restoring stashed local changes"
		if ! git -C "$repo" stash pop >/dev/null; then
			echo "[submodules] $path: stash pop needs manual resolution; stash entry was kept." >&2
			return 1
		fi
	fi

	echo "[submodules] $path: now on $(git -C "$repo" symbolic-ref --short HEAD) @ $(git -C "$repo" rev-parse --short HEAD)"
	if [[ -n "$backup_head_ref" ]]; then
		echo "[submodules] $path: preserved previous HEAD at $backup_head_ref"
	fi
	if [[ -n "$backup_branch_ref" ]]; then
		echo "[submodules] $path: preserved previous $branch at $backup_branch_ref"
	fi
}

remote_branch_head() {
	local repo="$1"
	local branch="$2"
	git -C "$repo" ls-remote --heads "$REMOTE" "$branch" | awk '{print $1}'
}

check_one() {
	local path="$1"
	local branch="$2"
	local repo="$REPO_ROOT/$path"
	local current_branch current_head dirty remote_head

	if [[ ! -d "$repo/.git" && ! -f "$repo/.git" ]]; then
		echo "[submodules] $path: not initialized. Run: make submodules-master" >&2
		return 1
	fi

	current_branch="$(git -C "$repo" symbolic-ref --short -q HEAD || true)"
	if [[ "$current_branch" != "$branch" ]]; then
		echo "[submodules] $path: expected branch $branch, found ${current_branch:-DETACHED}" >&2
		return 1
	fi

	dirty="$(git -C "$repo" status --porcelain --untracked-files=all)"
	if [[ -n "$dirty" ]]; then
		echo "[submodules] $path: has uncommitted changes" >&2
		printf '%s\n' "$dirty" | sed 's/^/[submodules]   /' >&2
		return 1
	fi

	current_head="$(git -C "$repo" rev-parse HEAD)"
	remote_head="$(remote_branch_head "$repo" "$branch")"
	if [[ -z "$remote_head" ]]; then
		echo "[submodules] $path: cannot resolve $REMOTE/$branch" >&2
		return 1
	fi

	if [[ "$current_head" == "$remote_head" ]]; then
		echo "[submodules] $path: OK $branch @ $(git -C "$repo" rev-parse --short HEAD)"
		return 0
	fi

	if git -C "$repo" cat-file -e "${remote_head}^{commit}" 2>/dev/null \
		&& git -C "$repo" merge-base --is-ancestor "$remote_head" "$current_head"; then
		echo "[submodules] $path: OK $branch is ahead of $REMOTE/$branch @ $(git -C "$repo" rev-parse --short HEAD)"
		return 0
	fi

	echo "[submodules] $path: not based on latest $REMOTE/$branch" >&2
	echo "[submodules]   local : $current_head" >&2
	echo "[submodules]   remote: $remote_head" >&2
	return 1
}

if [[ "$MODE" == "sync" ]]; then
	echo "[submodules] Syncing submodule URLs"
	git submodule sync -- "${SUBMODULE_PATHS[@]}"
	echo "[submodules] Initializing root submodules"
	git submodule update --init -- "${SUBMODULE_PATHS[@]}"

	for i in "${!SUBMODULE_PATHS[@]}"; do
		sync_one "${SUBMODULE_PATHS[$i]}" "${SUBMODULE_BRANCHES[$i]}"
	done

	echo "[submodules] Root submodule sync complete"
else
	failed=0
	for i in "${!SUBMODULE_PATHS[@]}"; do
		check_one "${SUBMODULE_PATHS[$i]}" "${SUBMODULE_BRANCHES[$i]}" || failed=1
	done
	if ((failed)); then
		echo "[submodules] Submodule check failed. Run: make submodules-master" >&2
		exit 1
	fi
	echo "[submodules] Root submodule check complete"
fi
