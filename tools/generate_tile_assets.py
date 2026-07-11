#!/usr/bin/env python3
import subprocess
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_IMAGE = PROJECT_ROOT / "res/source/tiles/麻将高清图.jpg"
OUTPUT_DIR = PROJECT_ROOT / "res/art/tiles"

TILE_WIDTH = 220
FRONT_TILE_HEIGHT = 320
BACK_FACE_WIDTH = 170
BACK_FACE_HEIGHT = 250

X_OFFSETS = [120, 392, 664, 936, 1208, 1480, 1752, 2024, 2296]
ROW_Y_OFFSETS = {
    "wan": 170,
    "tong": 470,
    "tiao": 840,
}

# Extract only the green panel from the back tile so we can embed it inside
# our runtime-drawn tile shell without including shelf lines from the source photo.
BACK_FACE_OFFSET = (1225, 420)


def run_sips(height: int, width: int, offset_y: int, offset_x: int, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "sips",
            "-c",
            str(height),
            str(width),
            "--cropOffset",
            str(offset_y),
            str(offset_x),
            str(SOURCE_IMAGE),
            "--out",
            str(output_path),
        ],
        check=True,
    )


def main() -> None:
    if not SOURCE_IMAGE.exists():
        raise FileNotFoundError(f"Missing source image: {SOURCE_IMAGE}")

    for suit, offset_y in ROW_Y_OFFSETS.items():
        for rank, offset_x in enumerate(X_OFFSETS, start=1):
            run_sips(
                FRONT_TILE_HEIGHT,
                TILE_WIDTH,
                offset_y,
                offset_x,
                OUTPUT_DIR / f"{suit}_{rank}.jpg",
            )

    run_sips(
        BACK_FACE_HEIGHT,
        BACK_FACE_WIDTH,
        BACK_FACE_OFFSET[0],
        BACK_FACE_OFFSET[1],
        OUTPUT_DIR / "back_face.jpg",
    )

    print(f"Generated tile assets in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
