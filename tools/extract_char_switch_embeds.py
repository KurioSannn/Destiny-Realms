from __future__ import annotations

import base64
import re
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "public" / "Hud Exsplor" / "CHAR SWIITCH 3.svg"
OUTPUT = ROOT / "public" / "Hud Exsplor" / "generated"


def main() -> None:
    svg = SOURCE.read_text(encoding="utf-8")
    matches = re.findall(
        r'<image\s+id="([^"]+)"[^>]*?xlink:href="data:image/png;base64,([^"]+)"',
        svg,
    )
    if len(matches) != 2:
        raise RuntimeError(f"Expected 2 embedded PNGs, found {len(matches)}")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, (image_id, encoded) in enumerate(matches):
        payload = base64.b64decode(encoded)
        if payload[:8] != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError(f"{image_id} is not a PNG")
        width, height = struct.unpack(">II", payload[16:24])
        destination = OUTPUT / f"char_switch_3_image_{index}.png"
        destination.write_bytes(payload)
        print(f"{destination.relative_to(ROOT)}: {width}x{height}")


if __name__ == "__main__":
    main()
