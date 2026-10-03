#!/usr/bin/env python3
"""Write an original short pop used when a cell clears.

The app bundles the base64 text. This script also writes build/clear.wav
so you can listen to the same bytes.
"""

import base64
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
B64_PATH = ROOT / "Convey" / "clear.wav.b64"
WAV_PATH = ROOT / "build" / "clear.wav"

RATE = 22050
SECONDS = 0.09


def samples() -> list[int]:
    count = int(RATE * SECONDS)
    frames: list[int] = []
    for index in range(count):
        t = index / RATE
        envelope = math.exp(-t * 42)
        tone = math.sin(2 * math.pi * (760 - 380 * (t / SECONDS)) * t)
        partial = math.sin(2 * math.pi * 1210 * t)
        value = envelope * (0.72 * tone + 0.28 * partial)
        frames.append(int(max(-1.0, min(1.0, value)) * 32767))
    return frames


def wav_bytes(frames: list[int]) -> bytes:
    import io

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", sample) for sample in frames))
    return buffer.getvalue()


def main() -> None:
    payload = wav_bytes(samples())
    with wave.open(__import__("io").BytesIO(payload)) as handle:
        if handle.getnframes() < 100 or handle.getframerate() != RATE:
            raise SystemExit("generated wav failed to read back")
    B64_PATH.write_text(base64.b64encode(payload).decode("ascii") + "\n")
    WAV_PATH.parent.mkdir(parents=True, exist_ok=True)
    WAV_PATH.write_bytes(payload)
    print(f"wrote {B64_PATH} ({len(payload)} bytes)")


if __name__ == "__main__":
    main()
