#!/usr/bin/env python3
"""
c-hook/scripts/write-meta.py

Writes hook-meta.json after the hook clip is produced.

Usage:
    python3 write-meta.py \
        --clip  /path/to/hook-clip.mp4 \
        --words /path/to/hook-words.json   # optional; omit or pass '' when TRANSCRIBE=false
        --out   /path/to/hook-meta.json
"""

import argparse
import json
import os
import subprocess
import sys


def get_duration(clip_path: str) -> float:
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "csv=p=0",
            clip_path,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return round(float(result.stdout.strip()), 3)


def load_words(words_path: str):
    if not words_path or not os.path.isfile(words_path):
        return None
    with open(words_path) as f:
        data = json.load(f)
    # Whisper JSON wraps segments; normalise to [{text,start,end}] word list
    if isinstance(data, list):
        return data
    # Whisper native format: {"segments": [{"words": [...]}]}
    words = []
    for seg in data.get("segments", []):
        for w in seg.get("words", []):
            words.append({"text": w.get("word", "").strip(),
                          "start": w.get("start", 0),
                          "end": w.get("end", 0)})
    return words if words else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clip",  required=True)
    parser.add_argument("--words", default="")
    parser.add_argument("--out",   required=True)
    args = parser.parse_args()

    if not os.path.isfile(args.clip):
        sys.exit(f"[c-hook/write-meta] ERROR: clip not found: {args.clip}")

    duration = get_duration(args.clip)
    words    = load_words(args.words)

    meta = {
        "path":     os.path.abspath(args.clip),
        "duration": duration,
        "words":    words,
    }

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(meta, f, indent=2)

    print(f"[c-hook] hook-meta.json written: duration={duration}s, "
          f"words={'yes' if words else 'null'}")


if __name__ == "__main__":
    main()
