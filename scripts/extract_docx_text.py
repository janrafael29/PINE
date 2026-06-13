"""Extract paragraph text from a .docx (document.xml) to UTF-8 plain text."""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: extract_docx_text.py <document.xml> <out.txt>", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    root = ET.parse(src).getroot()
    out: list[str] = []
    for p in root.iter(f"{W}p"):
        parts: list[str] = []
        for node in p.iter(f"{W}t"):
            if node.text:
                parts.append(node.text)
            if node.tail:
                parts.append(node.tail)
        line = "".join(parts).strip()
        if line:
            out.append(line)
    text = "\n".join(out)
    dst.write_text(text, encoding="utf-8")
    print(f"wrote {len(out)} paragraphs, {len(text)} chars -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
