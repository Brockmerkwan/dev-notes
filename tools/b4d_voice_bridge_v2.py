#!/usr/bin/env python3
import numpy as np, sounddevice as sd, queue, time
from faster_whisper import WhisperModel
from rich.console import Console

console = Console()
SAMPLE_RATE = 44100
CHANNEL = 1
FRAME = 1024
THRESH = 0.003
MIN_SPEECH_SEC = 0.5
MODEL = "base"

def is_voice(x):
    rms = np.sqrt(np.mean(np.square(x)))
    return rms > THRESH

def main():
    q = queue.Queue()
    model = WhisperModel(MODEL, device="cpu")
    def cb(indata, frames, t, status):
        if status: console.print(status)
        q.put(indata[:, CHANNEL].copy())

    with sd.InputStream(channels = 1, samplerate=SAMPLE_RATE, dtype="float32", callback=cb):
        console.print("🎙 [green]Listening with VAD (Right channel)… Ctrl+C to stop[/green]")
        buf, last_voice = np.zeros(0, np.float32), 0
        while True:
            x = q.get()
            if is_voice(x):
                buf = np.append(buf, x)
                last_voice = time.time()
            elif time.time() - last_voice > MIN_SPEECH_SEC and len(buf) > 0:
                segs, _ = model.transcribe(buf, beam_size=1)
                for s in segs:
                    if s.text.strip():
                        console.print(f"[cyan][{time.strftime('%H:%M:%S')}] {s.text.strip()}[/cyan]")
                buf = np.zeros(0, np.float32)

try:
    main()
except KeyboardInterrupt:
    console.print("\n🛑 [yellow]Stopped.[/yellow]")
