#!/usr/bin/env bash
# git_loop.sh — Brock Core OS Git loop (stage → commit → tag → push)
# Supports --dry-run, --repo PATH, --tag auto|major|minor|patch|vX.Y.Z
set -euo pipefail

DRY=0
REPO="${REPO:-$PWD}"
REMOTE="${REMOTE:-origin}"
BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
TAG_MODE=""

usage(){ echo "Usage: $(basename "$0") [--repo PATH] [--tag auto|major|minor|patch|vX.Y.Z] [--dry-run]"; }

msg(){ echo "$*"; }
run(){ [ "$DRY" -eq 1 ] && echo "[dry-run] $*" || eval "$@"; }

bump(){
  local part="$1"; local latest next major minor patch
  latest="$(git -C "$REPO" describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)"
  IFS=. read -r major minor patch <<<"${latest#v}"
  case "$part" in
    major) next="v$((major+1)).0.0" ;;
    minor) next="v${major}.$((minor+1)).0" ;;
    patch) next="v${major}.${minor}.$((patch+1))" ;;
    *)     next="$part" ;;
  esac
  echo "$next"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift ;;
    --tag)  TAG_MODE="$2"; shift ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
  esac; shift
done

msg "Repo: $REPO"
msg "Branch: $BRANCH"

git -C "$REPO" status --short --branch

msg "Staging all..."
run git -C "$REPO" add -A

if git -C "$REPO" diff --cached --quiet; then
  msg "Nothing to commit."
else
  printf "Type (feat/fix/chore/docs/etc): "; read -r TYPE
  TYPE="${TYPE:-chore}"
  printf "Scope (optional): "; read -r SCOPE
  printf "Message: "; read -r MSG
  COMMIT_MSG="${TYPE}${SCOPE:+(${SCOPE})}: ${MSG}"
  run git -C "$REPO" commit -m "$COMMIT_MSG"
fi

NEW_TAG=""
if [ -n "$TAG_MODE" ]; then
  case "$TAG_MODE" in
    auto) NEW_TAG="v$(date +%Y.%m.%d-%H%M)" ;;
    major|minor|patch) NEW_TAG="$(bump "$TAG_MODE")" ;;
    v*) NEW_TAG="$TAG_MODE" ;;
  esac
  run git -C "$REPO" tag -a "$NEW_TAG" -m "$NEW_TAG"
fi

run git -C "$REPO" push "$REMOTE" "$BRANCH"
[ -n "$NEW_TAG" ] && run git -C "$REPO" push "$REMOTE" "$NEW_TAG"

echo "---- Last 3 commits ----"
git -C "$REPO" --no-pager log -n 3 --oneline --decorate
echo "✅ git loop complete"
