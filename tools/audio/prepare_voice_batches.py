#!/usr/bin/env python3
"""Describe the grouped console synthesis needed for the optional voice packs.

The generated JSON is a work order for the browser UI and for the later
silence-splitting step. No speech service is called by this script.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "res/audio/voice_manifest.json"
OUTPUT = ROOT / "artifacts/voice_options_20260924/batches.json"

VOICES = [
    ("sichuan_xiaotian_2", "小天 2.0", "sichuan", "male"),
    ("sichuan_kuailexiaodong_2", "快乐小东 2.0", "sichuan", "male"),
    ("mandarin_baqiqingshu_2", "霸气青叔 2.0", "mandarin", "male"),
    ("mandarin_huolixiaoge_2", "活力小哥 2.0", "mandarin", "male"),
    ("mandarin_fanjuanqingnian_2", "反卷青年 2.0", "mandarin", "male"),
    ("sichuan_xiaohe_2", "小何 2.0", "sichuan", "female"),
    ("mandarin_wuzetian_2", "武则天 2.0", "mandarin", "female"),
    ("mandarin_tiexinnvsheng_2", "贴心女声 2.0", "mandarin", "female"),
    ("mandarin_jitangmeimei_2", "鸡汤妹妹 2.0", "mandarin", "female"),
    ("mandarin_qiaopinvsheng_2", "俏皮女声 2.0", "mandarin", "female"),
]

INSTRUCTIONS = {
    "sichuan": "请严格使用自然、地道、清楚的四川成都话口音，像四川人打麻将时简短报牌，节奏短促，不要普通话腔。每句之间稍作停顿，不要添加文字以外的内容。",
    "mandarin": "请用自然、清楚的普通话，像打麻将时简短说话，节奏短促，不拖音。每句之间稍作停顿，不要添加文字以外的内容。",
}

ACTION_GROUPS = (
    ("actions_a", ("peng", "gang", "hu", "zimo", "qiang_gang_hu")),
    ("actions_b", ("gang_shang_hua", "gang_shang_pao", "pass", "win", "lose")),
    ("actions_c", ("bao_jiao", "bao_gang", "ding_que_wan", "ding_que_tiao", "ding_que_tong")),
)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    batches = []
    for voice_id, name, language, gender in VOICES:
        actions = manifest["profiles"][f"{language}_{gender}"]["actions"]
        groups = []
        for suit in ("tong", "tiao", "wan"):
            keys = [f"{suit}_{rank}" for rank in range(1, 10)]
            texts = [manifest["tile_texts"][key] for key in keys]
            groups.append({"group": suit, "keys": keys, "texts": texts, "input": "。".join(texts) + "。"})
        for group_name, keys in ACTION_GROUPS:
            texts = [actions[key] for key in keys]
            groups.append({"group": group_name, "keys": list(keys), "texts": texts, "input": "。".join(texts) + "。"})
        batches.append({
            "id": voice_id,
            "name": name,
            "language": language,
            "gender": gender,
            "instruction": INSTRUCTIONS[language],
            "directory": f"voice_options/{voice_id}",
            "groups": groups,
        })
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(batches, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(batches)} voices, {sum(len(v['groups']) for v in batches)} grouped syntheses: {OUTPUT}")


if __name__ == "__main__":
    main()
