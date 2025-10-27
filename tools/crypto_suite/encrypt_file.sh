#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="$HOME/.local/state/crypto_suite"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/encrypt_$(date +%F_%H-%M-%S).log"

usage() { echo "Usage: $0 <file> [--age|--openssl]"; exit 1; }
[[ $# -lt 1 ]] && usage
FILE="$1"; shift || true
METHOD="${1:---age}"
[[ ! -f "$FILE" ]] && { echo "❌ File not found: $FILE"; exit 1; }

OUT="${FILE}.enc"
case "$METHOD" in
  --openssl) echo "🔒 OpenSSL AES-256-CBC..."; openssl enc -aes-256-cbc -salt -in "$FILE" -out "$OUT" ;;
  --age|*)   echo "🔒 age encryption..."; age -p -o "$OUT" "$FILE" ;;
esac

echo "✅ Created $OUT" | tee -a "$LOG_FILE"
read -p "Shred plaintext file? (y/N): " wipe
[[ "$wipe" == [yY]* ]] && { shred -u "$FILE"; echo "🧹 Shredded $FILE"; }
ls -lh "$OUT"
