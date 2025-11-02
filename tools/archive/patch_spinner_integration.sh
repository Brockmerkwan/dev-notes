#!/usr/bin/env zsh
set -euo pipefail
cd ~/Projects/devnotes

SPINNER="$PWD/tools/ux_spinner.sh"
[[ -f "$SPINNER" ]] || { echo "❌ Spinner script missing at $SPINNER"; exit 1; }

inject_spinner() {
  local target="$1"
  local bak="$target.bak.$(date +%F_%H-%M-%S)"
  cp "$target" "$bak"
  echo "🧩 Patching $target (backup → ${bak##*/})"

  # Remove existing spinner lines
  grep -v "ux_spinner.sh" "$target" > "${target}.tmp" || true

  # Build patched version line-by-line (Zsh-safe)
  print "source \"$SPINNER\"" > "${target}.patched"
  print "" >> "${target}.patched"
  print "start_spinner \"Running ${target:t}\"" >> "${target}.patched"
  print "" >> "${target}.patched"
  cat "${target}.tmp" >> "${target}.patched"
  print "" >> "${target}.patched"
  print "stop_spinner \"${target:t} complete\"" >> "${target}.patched"

  mv -f "${target}.patched" "$target"
  rm -f "${target}.tmp"
  chmod +x "$target"

  if zsh -n "$target"; then
    echo "✅ Syntax OK: ${target:t}"
  else
    echo "⚠️ Syntax issue: ${target:t}"
  fi
}

# Patch main automation scripts
for f in core.sh daily_rotate.sh tools/devhealth.sh; do
  if [[ -f "$f" ]]; then
    inject_spinner "$f"
  else
    echo "ℹ️ Skipping missing: $f"
  fi
done

echo "🪄 Spinner integration complete."
