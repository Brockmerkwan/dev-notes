#!/usr/bin/env python3
import subprocess, sys
from faster_whisper import WhisperModel
import sounddevice as sd
import numpy as np
import ollama
from pathlib import Path
from datetime import datetime
import os
os.environ["OMP_NUM_THREADS"] = "1"

# === Load Sith Research Context ===
SITH_PATH = Path.home() / "Projects/devnotes/agents/sith/lore/sith_code.txt"
ORIGIN_PATH = Path.home() / "Projects/devnotes/agents/sith/lore/b4d_origin.md"
SITH_CONTEXT = ""
if SITH_PATH.exists():
    with open(SITH_PATH, "r") as f:
        SITH_CONTEXT += f.read() + "\n\n"
if ORIGIN_PATH.exists():
    with open(ORIGIN_PATH, "r") as f:
        SITH_CONTEXT += f.read()

model = WhisperModel("small", device="cpu", compute_type="int8")

def record(seconds=5, rate=16000):
    print("🎙️ Speak...")
    data = sd.rec(int(seconds * rate), samplerate=rate, channels=1, dtype="float32")
    sd.wait()
    return np.squeeze(data)

def transcribe(audio):
    segments, _ = model.transcribe(audio)
    text = " ".join([s.text for s in segments])
    print(f"🗣️ You: {text}")
    return text

def query_llm(prompt):
    system_prompt = (
        "You are B4D, a synthetic intelligence who speaks with the calm authority of a Sith Lord. "
        "When asked about the Sith or similar topics, respond factually and in-character. "
        "Use the following knowledge as your lore foundation:\n\n"
        f"{SITH_CONTEXT}\n\n"
        "Maintain a composed, precise tone at all times."
    )
    r = ollama.chat(
        model="brock-core",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt},
        ],
        options={"num_predict": 512, "stream": False},
    )
    reply = r["message"]["content"]
    print(f"🤖 LLM: {reply}")
    return reply

# === Piper Configuration ===
PIPER_MODEL = str(Path.home() / ".local/share/piper/voices/en_US/ryan/high_fixed/en_US-ryan-high.onnx")
VOICE_DIR = Path.home() / ".local/state/b4d/voice_logs"
VOICE_DIR.mkdir(parents=True, exist_ok=True)

def speak(text: str):
    """Generate speech with Piper + play audio"""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    wav_path = VOICE_DIR / f"{timestamp}.wav"

    cmd = [
        "piper",
        "--model", PIPER_MODEL,
        "--output_file", str(wav_path),
        "--length_scale", "0.9",  # controls speech rate
        "--noise_scale", "0.3",   # clarity (0.3–0.7 typical)
        "--noise_w", "0.7",       # tone grit (0.6–0.9 for robotic)
    ]

    subprocess.run(cmd, input=text.encode(), check=True)
    subprocess.run(["afplay", str(wav_path)])

if __name__ == "__main__":
    speak("B4D systems online. Awaiting your command My lord.")

COMMAND_RESPONSES = {
    "shutdown": "🛑 System powering down.",
    "stop": "🛑 Stopping as ordered.",
    "quiet": "🔇 Entering silent mode.",
    "exit": "🛑 Exiting session."
}

COMMANDS = {
    "shutdown": ["shutdown", "shut down", "power off", "end program"],
    "stop": ["stop", "cease", "halt"],
    "quiet": ["quiet", "silence", "mute", "be quiet"],
    "exit": ["exit", "quit", "terminate", "close"],
}

def handle_command(text):
    """Check for simple voice commands before sending to LLM"""
    text_l = text.lower()
    for cmd, variants in COMMANDS.items():
        for v in variants:
            if v in text_l:
                speak(COMMAND_RESPONSES[cmd])
                raise KeyboardInterrupt

try:
    while True:
        audio = record(4)
        text = transcribe(audio)
        handle_command(text)
        if not text.strip(): continue
        reply = query_llm(text)
        speak(reply)
except KeyboardInterrupt:
    print("🛑 B4D shutting down gracefully.")