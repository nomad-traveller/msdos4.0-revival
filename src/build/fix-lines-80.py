#!/usr/bin/env python3
"""Rewrite a 1988 MASM source so every line is <= 80 bytes, keeping the
code bytes semantically identical:

 1. The repo stores the original CP437 box-drawing characters of some
    banner/comment lines as UTF-8-encoded U+FFFD (3 bytes, EF BF BD
    each). MASM 4.x has a ~128-byte line buffer, so a comment line with
    ~40 of these is >128 bytes and aborts with "A2106: Line too long".
    They are pure comments -> replace each triple with the single CP437
    byte 0xB0 (light shade), restoring the visual style at 1 byte/char.

 2. Lines >80 bytes are shortened:
      - comment lines: hard-wrapped with ';' on continuation lines,
      - code lines: internal whitespace runs squeezed (leading indent
        tabs kept). The trailing ";ANnnn; text" comment keeps its tag on
        the code line if it fits, otherwise the whole comment moves to a
        comment-only line above. Comments carry no semantics for MASM.

Lines already <=80 bytes are left byte-for-byte untouched.

Usage: fix-lines-80.py <file>   (in-place, CRLF preserved)
"""
import re
import sys

MOJIBAKE = b"\xef\xbf\xbd"


def squeeze(line: str) -> str:
    """Collapse internal whitespace runs; keep leading indent as tabs."""
    stripped = line.lstrip(" \t")
    indent = line[: len(line) - len(stripped)]
    n_tabs = indent.count("\t")
    body = re.sub(r"[ \t]+", " ", stripped).rstrip()
    return "\t" * n_tabs + body


def wrap_comment(text: str, out: list) -> None:
    while text:
        chunk = text[:78]
        cut = chunk.find("\t")
        if cut != -1:
            chunk = chunk[:cut]
        out.append(";" + chunk.rstrip())
        text = text[len(chunk) :].lstrip()


def main() -> None:
    path = sys.argv[1]
    data = open(path, "rb").read()
    data = data.replace(MOJIBAKE, b"\xb0")     # comments only (verified)
    text = data.decode("latin1")
    lines = text.splitlines()
    out: list = []
    for line in lines:
        if len(line) <= 80:                    # untouched (but never longer
            out.append(line)                   # exists after step 1)
            continue
        bare = line.split(";", 1)
        if line.lstrip().startswith(";"):
            wrap_comment(line.lstrip()[1:], out)
            continue
        if len(bare) == 2:                     # code;tag; possibly more text
            code, comment = squeeze(bare[0]), ";" + bare[1].strip()
            tagm = re.match(r";(AN\d+);(?:\s*(.*))?$", comment)
            if tagm:
                tag, text2 = tagm.group(1), (tagm.group(2) or "").strip()
                cand = f"{code}\t;{tag};"
                if len(cand) <= 79 and text2:
                    out.append(f";{tag} {text2}")
                    out.append(cand)
                    continue
                if len(cand) <= 79:            # tag only, no text
                    out.append(cand)
                    continue
                if len(text2):
                    wrap_comment(f"{tag} {text2}", out)
            out.append(code)
            continue
        out.append(squeeze(line))              # pure code, no comment
    fixed = "\r\n".join(out) + "\r\n"
    open(path, "wb").write(fixed.encode("latin1"))
    print(f"{path}: {len(lines)} lines -> {len(out)} lines")


if __name__ == "__main__":
    main()