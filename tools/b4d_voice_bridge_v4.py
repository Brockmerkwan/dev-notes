#!/usr/bin/env python3
"""
b4d_voice_bridge_v4.py — Real-time voice to text → LLM bridge
Phase 2 integration with b4d_chat_bridge.sh
"""
import sys, os, time, json, signal, queue, requests, numpy as np, sounddevice as sd
import faster_whisper

SAMPLE_RATE = 16000
BLOCK_SIZE = 1024
# THRESHOLD = 0.002
OLLAMA_API = "http://localhost:11434/api/generate"
MODEL = "brock-core"

LOG_DIR = os.path.expanduser("~/.local/state/brock-core")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "voice.log")

audio_q = queue.Queue()
running = True

def handle_sigint(sig, frame):
    global running
    print("\n[b4d] 🛑 Stopped by user.")
    running = False
signal.signal(signal.SIGINT, handle_sigint)

import time

def calibrate_threshold(duration=2.0):
    print(f"🧩 Calibrating ambient noise for {duration}s...")
    buf = []
    with sd.InputStream(device=1, samplerate=16000, channels=1, blocksize=1024) as s:
        start = time.time()
        while time.time() - start < duration:
            d, _ = s.read(1024)
            buf.append(np.sqrt(np.mean(d ** 2)))
    noise_floor = np.mean(buf)
    threshold = max(noise_floor * 5, 0.005)
    print(f"📊 Ambient RMS={noise_floor:.6f} → Threshold={threshold:.6f}")
    return threshold

THRESHOLD = calibrate_threshold()

print("🎙 b4d_voice_bridge_v4 — Real-time Whisper bridge")
model = faster_whisper.WhisperModel("base", device="cpu", compute_type="int8")
print("🧠 Whisper model loaded (base/int8)")
print("🎧 Listening... Ctrl+C to stop")

def callback(indata, frames, time_info, status):
    if status:
        print(status, file=sys.stderr)
    audio_q.put(indata.copy())

def rms(audio): return np.sqrt(np.mean(np.square(audio)))

with sd.InputStream(device=1, samplerate=SAMPLE_RATE, channels=1, blocksize=BLOCK_SIZE, callback=callback):
    buffer = np.zeros((0,), dtype=np.float32)
    silence_count = 0
    while running:
        try:
            data = audio_q.get(timeout=0.1)
        except queue.Empty:
            continue
        audio = data.flatten()
        audio = np.clip(audio * 50, -1.0, 1.0)  # pre-gain boost for quiet mic input
        print(f"🎚️ RMS={rms(audio):.6f}")
        buffer = np.concatenate((buffer, audio))
        level = rms(audio)
        silence_count = silence_count + 1 if level < THRESHOLD else 0
        if silence_count > 5 and len(buffer) > SAMPLE_RATE * 0.4:
            duration = len(buffer) / SAMPLE_RATE
            print(f"🟢 Detected block ({duration:.2f}s, rms={level:.3f})")
            audio_data = np.copy(buffer)
            buffer = np.zeros((0,), dtype=np.float32)
            silence_count = 0
            if duration < 0.4:
                print("⏩ Skipped (too short)")
                continue
            print(f"🌀 Transcribing ({duration:.1f}s)...")
            segments, _ = model.transcribe(audio_data, beam_size=1)
            text = " ".join([seg.text.strip() for seg in segments]).strip()
            if not text: continue
            print(f"[{time.strftime('%H:%M:%S')}] {text}")
            with open(LOG_FILE, "a") as f:
                f.write(f"[{time.strftime('%H:%M:%S')}] {text}\n")
            payload = {"model": MODEL, "prompt": text, "stream": False}
            try:
                resp = requests.post(OLLAMA_API, json=payload, timeout=60)
                reply = "".join(json.loads(line)["response"]
                                for line in resp.iter_lines(decode_unicode=True)
                                if line.strip() and "response" in json.loads(line))
                reply = reply.strip()
                print(f"🤖 {reply if reply else '(no response)'}")
            except Exception as e:
                print(f"⚠️ LLM error: {e}")
print("🛑 Voice bridge ended.")