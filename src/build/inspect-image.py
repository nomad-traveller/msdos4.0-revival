#!/usr/bin/env python3
"""Read-only gate inspector for the MS-DOS 4.00 720K floppy image.

Usage:    python3 inspect-image.py [img] [msboot.bin]
Defaults: <this dir>/msdos400.img and ../bin/msboot.bin

Layout: sector 0 boot, sectors 1-3 FAT1, sectors 4-6 FAT2,
        sectors 7-13 root dir (112 entries), sector 14+ data, 1024 B/cluster.
Exit 0 = all gates PASSED, 1 = at least one FAILED.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IMG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "msdos400.img")
BOOT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "bin", "msboot.bin")

BPB_DIFF_OFFSETS = {0x0D, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x18, 0x1A, 0x1C, 0x24}
ROOT_EXPECT = [("IO      SYS", 2), ("MSDOS   SYS", 35),
               ("COMMAND COM", 72), ("DOS        ", 109)]

fails = []


def gate(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" ({detail})" if detail else ""))
    if not ok:
        fails.append(name)


def get12(fat, i):
    o = (i * 3) // 2
    v = fat[o] | (fat[o + 1] << 8)
    return (v >> 4) if (i & 1) else (v & 0xFFF)


def chain(fat, start):
    out, c = [], start
    while 2 <= c < 0xFF8:
        out.append(c)
        c = get12(fat, c)
    return out


def main():
    img = open(IMG, "rb").read()
    msb = open(BOOT, "rb").read()[-512:]   # exe2bin put the boot loader in the LAST sector
    gate("size == 737280", len(img) == 737280, f"got {len(img)}")

    b = img[:0x3E]
    bps = int.from_bytes(b[0x0B:0x0D], "little")
    spc, res, nfats, ents = b[0x0D], int.from_bytes(b[0x0E:0x10], "little"), b[0x10], int.from_bytes(b[0x11:0x13], "little")
    tot, media, spf = int.from_bytes(b[0x13:0x15], "little"), b[0x15], int.from_bytes(b[0x16:0x18], "little")
    spt, heads = int.from_bytes(b[0x18:0x1A], "little"), int.from_bytes(b[0x1A:0x1C], "little")
    geo = (bps, spc, res, nfats, ents, tot, media, spf, spt, heads)
    gate("BPB = 720K FAT12 (512/2/1/2/112/1440/0xF9/3/9/2)",
         geo == (512, 2, 1, 2, 112, 1440, 0xF9, 3, 9, 2), f"got {geo}")

    diff = [i for i in range(512) if img[i] != msb[i]]
    gate("boot sector 0 == msboot.bin tail except BPB-geometry offsets",
         set(diff) == BPB_DIFF_OFFSETS,
         "diffs: " + " ".join(f"0x{i:02x}" for i in diff))

    fat1 = img[512:512 + spf * 512]
    fat2 = img[512 + spf * 512:512 + 2 * spf * 512]
    gate("FAT1[0] == FAT2[0] == F9 FF FF",
         fat1[:3] == b"\xF9\xFF\xFF" and fat2[:3] == b"\xF9\xFF\xFF",
         f"fat1={fat1[:3].hex()} fat2={fat2[:3].hex()}")

    root_off = (1 + 2 * spf) * 512
    data_off = (1 + 2 * spf + (ents * 32 + 511) // 512) * 512
    roots = []
    for i in range(ents):
        e = img[root_off + i * 32: root_off + (i + 1) * 32]
        if e[0] == 0x00:
            break
        if e[11] & 0x08 == 0:  # skip volume labels
            roots.append((e[:11].decode("ascii", "replace"),
                          int.from_bytes(e[26:28], "little")))
    gate("root order: IO=2 MSDOS=35 COMMAND=72 DOS=109",
         roots[:4] == ROOT_EXPECT, f"got {roots[:4]}")

    dos_c = dict(roots).get("DOS        ")
    dos_files = []
    for c in (chain(fat1, dos_c) if dos_c else []):
        s = data_off + (c - 2) * spc * 512
        for i in range(spc * 512 // 32):
            e = img[s + i * 32: s + (i + 1) * 32]
            if e[0] == 0x00:
                break
            if e[0] == 0xE5 or e[11] & 0x08:  # deleted or volume label
                continue
            if e[11] & 0x10 == 0:  # keep plain files
                dos_files.append((e[:11].decode("ascii", "replace"),
                                  int.from_bytes(e[26:28], "little")))
    gate("\\DOS holds 34 files", len(dos_files) == 34, f"got {len(dos_files)}")

    bin_dir = os.path.join(HERE, "..", "bin")
    clu = dict(roots)
    for n, c in dos_files:
        clu[n] = c
    ok_bad, bad = 0, []
    for fn in sorted(os.listdir(bin_dir)):
        if fn == "msboot.bin":
            continue
        want = open(os.path.join(bin_dir, fn), "rb").read()
        nm, _, ext = fn.partition(".")
        e = (nm.upper() + " " * 8)[:8] + (ext.upper() + " " * 3)[:3]
        if e not in clu:
            bad.append(f"{fn} not-on-disk")
            continue
        data = b"".join(img[data_off + (c - 2) * spc * 512:
                            data_off + (c - 1) * spc * 512]
                        for c in chain(fat1, clu[e]))
        if data[:len(want)] == want and all(x == 0 for x in data[len(want):]):
            ok_bad += 1
        else:
            bad.append(fn)
    gate("37/37 stored files byte-identical to bin/ originals",
         ok_bad == 37 and not bad, f"ok={ok_bad}" + (f" bad={bad}" if bad else ""))

    print("---")
    print("ALL GATES PASSED" if not fails else "FAILED: " + "; ".join(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())