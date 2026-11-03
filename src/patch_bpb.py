#!/usr/bin/env python3
"""Patch the BPB of the MS-DOS 4.00 boot sector (build/bin/msboot.bin)
for a 720 KiB double-sided floppy and write it as the boot sector of an
FAT image. The MS-DOS 4.00 boot loader carries its own BPB at offsets
0x0B..0x3D (identical layout to the DOS 4 extended BPB); FORMAT normally
patches these fields, we do it statically here.

Usage: patch_bpb.py <msboot.bin> <image.img>
"""
import sys

GEOM = {
    # field offset : 1/2-byte little-endian value
    0x0B: (2, 512),      # BytesPerSector
    0x0D: (1, 2),        # SectorsPerCluster
    0x0E: (2, 1),        # Reserved sectors
    0x10: (1, 2),        # Number of FATs
    0x11: (2, 0x70),     # Root directory entries (112)
    0x13: (2, 1440),     # Total sectors (16-bit)
    0x15: (1, 0xF9),     # Media descriptor
    0x16: (2, 3),        # Sectors per FAT
    0x18: (2, 9),        # Sectors per track
    0x1A: (2, 2),        # Number of heads
    0x1C: (4, 0),        # Hidden sectors (32-bit)
    0x20: (4, 0),        # Total sectors (32-bit) -> 0 = use 16-bit field
    0x24: (1, 0x00),     # Physical drive number (floppy)
    0x26: (1, 0x29),     # Extended boot signature (41)
}

def main():
    boot_path, img_path = sys.argv[1], sys.argv[2]
    boot = bytearray(open(boot_path, "rb").read())[-512:]
    for off, (size, val) in GEOM.items():
        boot[off:off + size] = (val).to_bytes(size, "little")
    # System ID must match the FAT type; with 1440 sectors it is FAT12.
    # NOTE: the slice must cover exactly 8 bytes (0x36..0x3D inclusive):
    # writing 8 bytes into a 7-byte slice expands the bytearray and shifts
    # the whole loader code after 0x3D by one byte -> silent boot hang.
    boot[0x36:0x3E] = b"FAT12   "
    with open(img_path, "r+b") as f:
        f.seek(0)
        f.write(bytes(boot))
        # mkfs.fat may stamp 0xAA as the media byte of FAT[0]; mtools and
        # MS-DOS require it to match the BPB media descriptor (0xF9 here),
        # followed by 0xFF (FAT12 EOC). Fix both FAT copies.
        for fat_off in [0x200 + 0 * 512, 0x200 + 3 * 512]:
            f.seek(fat_off)
            f.write(bytes([0xF9, 0xFF, 0xFF]))
    print("Patched MS-DOS 4.00 boot sector (720K BPB) into %s" % img_path)

if __name__ == "__main__":
    main()