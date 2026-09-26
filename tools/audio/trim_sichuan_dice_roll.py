"""Make a half-length dice sound without changing its pitch or sample rate."""

from array import array
from pathlib import Path
import sys
import wave


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "res/audio/sfx/mahjong_dice_roll.wav"
OUTPUT = ROOT / "res/audio/sfx/mahjong_dice_roll_short.wav"
DURATION_SECONDS = 1.5
FADE_SECONDS = 0.06


def main() -> None:
    with wave.open(str(SOURCE), "rb") as source:
        parameters = source.getparams()
        if parameters.nchannels != 1 or parameters.sampwidth != 2 or parameters.comptype != "NONE":
            raise ValueError("Expected uncompressed mono 16-bit PCM dice sound")
        frame_count = round(parameters.framerate * DURATION_SECONDS)
        samples = array("h")
        samples.frombytes(source.readframes(frame_count))
    if sys.byteorder != "little":
        samples.byteswap()
    fade_frames = round(parameters.framerate * FADE_SECONDS)
    for frame in range(frame_count - fade_frames, frame_count):
        gain = (frame_count - 1 - frame) / max(1, fade_frames - 1)
        samples[frame] = round(samples[frame] * gain)
    if sys.byteorder != "little":
        samples.byteswap()
    with wave.open(str(OUTPUT), "wb") as output:
        output.setparams(parameters)
        output.writeframes(samples.tobytes())
    print(f"Wrote {OUTPUT.name}: {frame_count / parameters.framerate:.3f}s at original pitch")


if __name__ == "__main__":
    main()
