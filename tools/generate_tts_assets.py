#!/usr/bin/env python3
import asyncio
import subprocess
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "res" / "audio" / "tts"
TMP_DIR = ROOT / ".tmp_tts"

VOICE_PACKS = {
    "male": "zh-CN-YunyangNeural",
    "female": "zh-CN-XiaoyiNeural",
}

VOICE_OPTIONS = {
    "male": {
        "rate": "+12%",
        "volume": "+38%",
        "pitch": "+0Hz",
    },
    "female": {
        "rate": "+10%",
        "volume": "+34%",
        "pitch": "+0Hz",
    },
}

RANK_TEXTS = {
    1: "一",
    2: "二",
    3: "三",
    4: "四",
    5: "五",
    6: "六",
    7: "七",
    8: "八",
    9: "九",
}

SUIT_TEXTS = {
    "tiao": "条",
    "tong": "筒",
    "wan": "万",
}

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


async def generate_mp3(text: str, voice: str, output_path: Path, rate: str, volume: str, pitch: str) -> None:
    communicate = edge_tts.Communicate(
        text=text,
        voice=voice,
        rate=rate,
        volume=volume,
        pitch=pitch,
    )
    await communicate.save(str(output_path))


def convert_to_wav(source_path: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "/opt/homebrew/bin/ffmpeg",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(source_path),
            "-af",
            "loudnorm=I=-18:LRA=7:TP=-1.5",
            "-ar",
            "22050",
            "-ac",
            "1",
            str(output_path),
        ],
        check=True,
    )


async def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    for pack_name, voice_name in VOICE_PACKS.items():
        pack_dir = OUTPUT_DIR / pack_name
        pack_dir.mkdir(parents=True, exist_ok=True)
        options = VOICE_OPTIONS[pack_name]

        for suit, suit_text in SUIT_TEXTS.items():
            for rank, rank_text in RANK_TEXTS.items():
                key = f"{suit}_{rank}"
                text = f"{rank_text}{suit_text}"
                tmp_mp3 = TMP_DIR / f"{pack_name}_{key}.mp3"
                out_wav = pack_dir / f"{key}.wav"
                await generate_mp3(text, voice_name, tmp_mp3, options["rate"], options["volume"], options["pitch"])
                convert_to_wav(tmp_mp3, out_wav)

        for action_key, action_text in ACTION_TEXTS.items():
            tmp_mp3 = TMP_DIR / f"{pack_name}_{action_key}.mp3"
            out_wav = pack_dir / f"{action_key}.wav"
            await generate_mp3(action_text, voice_name, tmp_mp3, options["rate"], options["volume"], options["pitch"])
            convert_to_wav(tmp_mp3, out_wav)

    print(f"Generated TTS assets in {OUTPUT_DIR}")


if __name__ == "__main__":
    asyncio.run(main())
