#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="$HOME/.local/state/fasterwhisper"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date +%F_%H-%M-%S).log"

# === Phase 1: Environment Check ===
echo "[1/4] Checking environment..." | tee -a "$LOG_FILE"
brew -v >/dev/null 2>&1 || { echo "Installing Homebrew..."; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }
brew install ffmpeg python@3.11 portaudio || true

# === Phase 2: Virtual Env + Install ===
echo "[2/4] Setting up venv..." | tee -a "$LOG_FILE"
cd "$HOME/Projects" || mkdir -p "$HOME/Projects" && cd "$HOME/Projects"
python3 -m venv fasterwhisper_env
source fasterwhisper_env/bin/activate

echo "[3/4] Installing Faster-Whisper stack..." | tee -a "$LOG_FILE"
pip install --upgrade pip wheel setuptools
pip install faster-whisper sounddevice numpy rich

# === Phase 3: Test Script ===
cat <<'PY' > test_fasterwhisper.py
import sounddevice as sd, numpy as np, tempfile, scipy.io.wavfile, sys
from faster_whisper import WhisperModel
model = WhisperModel("small")
fs = 16000
print("🎙️  Speak for 5 seconds...")
rec = sd.rec(int(fs*5), samplerate=fs, channels=1, dtype="float32"); sd.wait()
tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
scipy.io.wavfile.write(tmp.name, fs, (rec*32767).astype(np.int16))
segments, _ = model.transcribe(tmp.name)
print("🧠  Transcription:")
for seg in segments: print(seg.text)
PY

echo "[4/4] Running test..." | tee -a "$LOG_FILE"
python3 test_fasterwhisper.py | tee -a "$LOG_FILE"

# === Phase 4: Alias Command ===
PROFILE="$HOME/.zprofile"
if ! grep -q "alias transcribe-live=" "$PROFILE" 2>/dev/null; then
  echo "alias transcribe-live='source $HOME/Projects/fasterwhisper_env/bin/activate && python3 ~/Projects/test_fasterwhisper.py'" >> "$PROFILE"
  echo "✅ Added alias: transcribe-live"
fi

echo "✅ Faster-Whisper installed. Use 'transcribe-live' to start."

