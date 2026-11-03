#!/usr/bin/env python3
"""Scan all source files in the MS-DOS 4.00 tree for mojibake and replace it.

The upstream git repo stores some 1988 CP437 box-drawing/border characters
as UTF-8-encoded U+FFFD (the 3-byte sequence EF BF BD). MASM 4.x has a
~128-byte line buffer, so comment/data lines containing ~40 of these blow
past the limit with "A2106: Line too long". Each triple corresponds to
exactly ONE original file byte, so replacing it with a single '#' restores
the original byte geometry (line lengths, string lengths, panel W/L math).

For safety the script only touches plain-text source types and refuses
anything that contains a NUL byte (binaries such as .OBJ/.EXE/.DAT can
randomly contain the EF BF BD pattern and must not be rewritten).

For every file that is modified a copy of the unmodified original is
written first as <name>.ORIG (an existing .ORIG is never overwritten).

Usage:
    fix-mojibake.py [root] [--dry-run]

Defaults: root = <script dir>/.. (i.e. the src tree), live run.
"""
import os
import shutil
import sys

MOJIBAKE = b"\xef\xbf\xbd"          # UTF-8 encoding of U+FFFD
REPLACEMENT = b"#"                  # user-chosen one-byte substitute
TEXT_EXT = {".ASM", ".INC", ".MAC", ".EQU", ".SKL", ".MSG", ".TXT", ".INF"}
SKIP_BASENAMES = {"README-BUILD.md", "FIX-MOJIBAKE.PY", "FIX-LINES-80.PY"}


def max_line_bytes(data: bytes) -> int:
    return max((len(l) for l in data.splitlines()), default=0)


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry-run" in args
    rest = [a for a in args if not a.startswith("--")]
    root = os.path.abspath(rest[0]) if rest else \
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

    changed, total_triples = [], 0
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d.upper() not in {"BUILD", "BIN", "TOOLS", "LOG"}]
        for f in sorted(fn):
            up = f.upper()
            if up in SKIP_BASENAMES or up.endswith((".ORIG", ".BAK", ".OBJ", ".EXE", ".COM", ".SYS", ".BIN", ".DAT", ".LIB", ".LNK", ".MAP", ".IDX", ".CL1", ".CL2", ".CLA", ".CLB", ".CTL", ".HLP")):
                continue
            ext = os.path.splitext(f)[1].upper()
            if ext not in TEXT_EXT:
                continue
            path = os.path.join(dp, f)
            try:
                data = open(path, "rb").read()
            except OSError as e:
                print(f"  !! unreadable: {path}: {e}")
                continue
            n = data.count(MOJIBAKE)
            if not n:
                continue
            if b"\x00" in data:
                print(f"  !! skipped (binary NUL found): {path}")
                continue
            before = max_line_bytes(data)
            fixed = data.replace(MOJIBAKE, REPLACEMENT)
            after = max_line_bytes(fixed)
            rel = os.path.relpath(path, root)
            print(f"  {rel:45} {n:5} triples  {len(data):>8} -> {len(fixed):>8} B  maxline {before}->{after}")
            if dry:
                continue
            backup = path + ".ORIG"
            if os.path.exists(backup):
                print(f"     (existing backup kept: {os.path.basename(backup)})")
            else:
                shutil.copy2(path, backup)
            with open(path, "wb") as fh:
                fh.write(fixed)
            changed.append(path)
            total_triples += n

    print(f"\n== {'DRY RUN - ' if dry else ''}done: {len(changed)} files modified, {total_triples} mojibake sequences replaced with '#'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())