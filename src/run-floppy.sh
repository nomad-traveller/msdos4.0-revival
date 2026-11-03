#!/usr/bin/env bash
# Boot the assembled MS-DOS 4.00 floppy in DOSBox-X.
#
# NOTE: recent QEMU releases (10.2.1 / SeaBIOS on this host) silently
# refuse to boot from a floppy image in any configuration tried
# (-fda/-boot a, -drive if=floppy, isa-fdc.fdtypeA=144, 720K or 1440K
# media), so QEMU cannot be used as the boot tester here. DOSBox-X
# boots the image reliably and was used to verify the disk.
cd "$(cd "$(dirname "$0")" && pwd)/build"
# make the imgmount line portable to any tree location (see build_plan.md §0b)
IMG_ABS="$(pwd -P)/msdos400.img"
sed "s#^imgmount a .*#imgmount a $IMG_ABS -t floppy#" boottest.conf > _boottest.conf
exec dosbox-x -conf _boottest.conf "$@"