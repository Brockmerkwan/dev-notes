#!/usr/bin/env python3
import sounddevice as sd, numpy as np, queue, sys, time, os
from faster_whisper import WhisperModel
from rich.console import Console

console = Console()
LOG = os.path.expanduser("~/.local/state/fasterwhisper_live.log")
os.makedirs(os.path.dirname(LOG), exist_ok=True)

# audio / model config
DEVICE = (1, None)          # Scarlett 2i2
SR = 44100
BLOCK = 4096
model = WhisperModel("base", device="cpu")
q = queue.Queue()

def callback(indata, frames, time_info, status):
    if status: console.print(f"[yellow]{status}[/yellow]")
    q.put(indata.copy())

def main():
    console.print(f"[bold green]🎙 Live transcription started ({SR} Hz, channel 2)[/bold green]")
    with sd.InputStream(device=DEVICE, samplerate=SR, channels=2,
                        dtype="float32", blocksize=BLOCK, callback=callback):
        buf = np.zeros(0, dtype=np.float32)
        while True:
            data = q.get()
            if data.size == 0 or np.isnan(data).any(): continue
            ch2 = data[:,1]
            buf = np.append(buf, ch2)
            if len(buf) > SR * 5:               # ~5 s chunks
                seg = buf.copy(); buf = np.zeros(0, np.float32)
                segments, _ = model.transcribe(seg, beam_size=1)
                out = " ".join(s.text.strip() for s in segments)
                if out:
                    console.print(f"[cyan]{out}[/cyan]", soft_wrap=True)
                    with open(LOG, "a") as f: f.write(out + "\n")

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt:
        console.print("\n[red]🛑 Stopped.[/red]")
        sys.exit(0)
