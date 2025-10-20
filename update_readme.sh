#!/usr/bin/env bash
set -euo pipefail
REPO="$HOME/Projects/devnotes"
REP="$HOME/.local/share/brock/reports/sys_scan_latest.json"
[[ -f "$REP" ]] || { echo "[update_readme] no report: $REP"; exit 0; }

ts=$(jq -r '.timestamp' "$REP")
brew=$(jq -r '.counts.brew' "$REP")
cask=$(jq -r '.counts.cask' "$REP")
pip=$(jq -r '.counts.pip' "$REP")
npm=$(jq -r '.counts.npm' "$REP")
gem=$(jq -r '.counts.gem' "$REP")
status=$(jq -r '.status' "$REP")

badge() { # name value color
  echo "![${1}: ${2}](https://img.shields.io/badge/${1}-${2}-${3}.svg)"
}

cat > "$REPO/README.badges.md" <<MD
$(badge status "$status" "$([ "$status" = ok ] && echo "brightgreen" || echo "yellow")") \
$(badge brew "$brew" "$( [ "$brew" = 0 ] && echo brightgreen || echo orange)") \
$(badge cask "$cask" "$( [ "$cask" = 0 ] && echo brightgreen || echo orange)") \
$(badge pip "$pip"   "$( [ "$pip"  = 0 ] && echo brightgreen || echo orange)") \
$(badge npm "$npm"   "$( [ "$npm"  = 0 ] && echo brightgreen || echo orange)") \
$(badge gem "$gem"   "$( [ "$gem"  = 0 ] && echo brightgreen || echo orange)")

_Last scan: \`$ts\`_
MD

README="$REPO/README.md"
[[ -f "$README" ]] || { echo -e "# DevNotes\n\n<!-- SYS-BADGES:BEGIN -->\n<!-- SYS-BADGES:END -->" > "$README"; }

# Replace block between markers using perl (DOTALL)
perl -0777 -i -pe '
  my $badges = do { local $/; open my $fh, q{<}, q{README.badges.md} or die $!; <$fh> };
  s/(<!--\s*SYS-BADGES:BEGIN\s*-->)(.*?)(<!--\s*SYS-BADGES:END\s*-->)/$1\n$badges\n$3/s
' "$README"

cd "$REPO"
git add README.md README.badges.md
git commit -m "docs(readme): refresh status badges from latest sys_scan ($ts)" >/dev/null || true
git push >/dev/null || true
echo "[update_readme] ✅ README updated and pushed."

# --- stamp: update header timestamp + commit every run ---
REPO="${REPO:-$HOME/Projects/devnotes}"
NOW_ISO="$(date "+%Y-%m-%d %H:%M:%S")"
NOW_HUMAN="$(date "+%B %e, %Y at %l:%M %p" | sed 's/  / /g')"   # e.g., October 19, 2025 at 8:01 PM
GIT_SHA="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

# Case A: plain header style:  Last updated: <...> Current commit: <sha>
perl -0777 -i -pe '
  my ($now_h,$sha)=@ENV{qw/NOW_HUMAN GIT_SHA/};
  s/(^|\n)Last updated:\s*.*?(\s+Current commit:\s*).*$/$1."Last updated: $now_h$2$sha"/ems
' "$REPO/README.md"

# Case B: italic line: _Last updated: <...>_
perl -0777 -i -pe '
  my ($now_h)=@ENV{qw/NOW_HUMAN/};
  s/(^|\n)_Last updated:\s*.*?_/$1."_Last updated: $now_h_"/ems
' "$REPO/README.md"
