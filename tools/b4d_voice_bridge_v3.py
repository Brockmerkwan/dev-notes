#!/usr/bin/env python3
import sounddevice as sd, numpy as np, queue, time
from faster_whisper import WhisperModel
from rich.console import Console

MODEL_PATH = "base"
DEVICE = "cpu"
THRESH = 0.003
CHUNK_SEC = 1.0
SAMPLE_RATE = 44100

console = Console()
q = queue.Queue()

def cb(indata, frames, t, status):
    q.put(indata.copy())

def main():
    model = WhisperModel(MODEL_PATH, device=DEVICE)
    console.print("🎙 Listening (mono R-ch)… Ctrl+C to stop")
    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype='float32',
                        callback=cb, device=None):  # use system default
        buf = np.zeros(0, dtype=np.float32)
        while True:
            buf = np.append(buf, q.get())
            if len(buf) < SAMPLE_RATE * CHUNK_SEC:
                continue
            data, buf = buf.copy(), np.zeros(0, dtype=np.float32)
            if np.max(np.abs(data)) < THRESH:
                continue
            segs, _ = model.transcribe(data, beam_size=1)
            for s in segs:
                t = s.text.strip()
                if t:
                    console.print(f"[cyan][{time.strftime('%H:%M:%S')}] {t}[/cyan]")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n🛑 Stopped.")
