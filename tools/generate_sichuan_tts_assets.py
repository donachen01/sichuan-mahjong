#!/usr/bin/env python3
"""Generate the offline Sichuan-dialect Mahjong voice pack with CosyVoice 3.

The model and its environment are generation-time dependencies only. The game
ships the normalized WAV files and never loads a speech model at runtime.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "res" / "audio" / "tts_sichuan"

RANK_TEXTS = {1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九"}
SUIT_TEXTS = {"tiao": "条", "tong": "筒", "wan": "万"}
ACTION_TEXTS = {
    "peng": "碰",
    "gang": "杠",
    "hu": "胡",
    "zimo": "自摸",
    "bao_jiao": "报叫",
    "bao_gang": "报杠",
    "pass": "过",
    "win": "赢了",
    "lose": "输了",
    "ding_que_wan": "缺万",
    "ding_que_tiao": "缺条",
    "ding_que_tong": "缺筒",
}


def phrases() -> list[tuple[str, str]]:
    result: list[tuple[str, str]] = []
    for suit, suit_text in SUIT_TEXTS.items():
        for rank, rank_text in RANK_TEXTS.items():
            result.append((f"{suit}_{rank}", f"{rank_text}{suit_text}"))
    result.extend(ACTION_TEXTS.items())
    return result


def normalize(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "/opt/homebrew/bin/ffmpeg", "-loglevel", "error", "-y",
            "-i", str(source), "-af", "loudnorm=I=-18:LRA=7:TP=-1.5",
            "-ar", "22050", "-ac", "1", str(destination),
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cosyvoice-root", required=True, type=Path)
    parser.add_argument("--model-dir", required=True, type=Path)
    args = parser.parse_args()

    sys.path.insert(0, str(args.cosyvoice_root))
    sys.path.insert(0, str(args.cosyvoice_root / "third_party" / "Matcha-TTS"))
    import torchaudio
    from cosyvoice.cli.cosyvoice import AutoModel

    model = AutoModel(model_dir=str(args.model_dir), fp16=False)
    instruction = "请用自然、清楚、简短的四川话表达，像牌桌报牌一样。<|endofprompt|>"
    with tempfile.TemporaryDirectory(prefix="sichuan_tts_") as temp_dir:
        temp_root = Path(temp_dir)
        for gender, speaker in (("male", "中文男"), ("female", "中文女")):
            for key, text in phrases():
                raw_path = temp_root / f"{gender}_{key}.wav"
                outputs = list(model.inference_instruct(text, speaker, instruction, stream=False))
                if len(outputs) != 1:
                    raise RuntimeError(f"expected one audio result for {gender}/{key}, got {len(outputs)}")
                torchaudio.save(str(raw_path), outputs[0]["tts_speech"], model.sample_rate)
                normalize(raw_path, OUTPUT_DIR / gender / f"{key}.wav")
                print(f"generated {gender}/{key}", flush=True)

    print(f"Generated {len(phrases()) * 2} Sichuan voice assets in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
