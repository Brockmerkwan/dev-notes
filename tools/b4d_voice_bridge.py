#!/usr/bin/env python3
import os, sys, queue, time, json, numpy as np, sounddevice as sd
from faster_whisper import WhisperModel
from rich.console import Console

console = Console()
log_dir = os.path.expanduser("~/.local/state")
os.makedirs(log_dir, exist_ok=True)
log_path = os.path.join(log_dir, "b4d_voice.log")

DEVICE_INDEX = 1
SAMPLE_RATE = 44100
CHUNK_SEC = 5
NOISE_GATE = 0.05  # tuned from your 0.145 peak
model = WhisperModel("base", device="cpu")
q = queue.Queue()

def callback(indata, frames, time_info, status):
    if status:
        console.print(f"[yellow]Audio warning:[/yellow] {status}")
    # Only take Channel 2 (right)
    q.put(indata[:,1].copy())

def log_line(txt):
    with open(log_path, "a") as f:
        f.write(json.dumps({
            "ts": time.strftime("%Y-%m-%d %H:%M:%S"),
            "text": txt
        }) + "\n")

def main():
    console.print(f"[bold green]🎙 Listening on Scarlett Ch2 — Ctrl+C to stop[/bold green]")
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=2, device=DEVICE_INDEX,
                        dtype="float32", callback=callback):
        buf = np.zeros(0, dtype=np.float32)
        while True:
            buf = np.append(buf, q.get())
            if len(buf) > SAMPLE_RATE * CHUNK_SEC:
                data = buf.copy()
                buf = np.zeros(0, dtype=np.float32)
                if np.max(np.abs(data)) < NOISE_GATE:
                    continue
                segs, _ = model.transcribe(data, beam_size=1)
                for s in segs:
                    t = s.text.strip()
                    if t:
                        console.print(f"[cyan][{time.strftime('%H:%M:%S')}] {t}[/cyan]")
                        log_line(t)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[red]🛑 Stopped.[/red]")
        sys.exit(0)
