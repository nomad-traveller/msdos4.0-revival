# MS-DOS 4.00 Source (revival)

## Introduction

This repository is a source-preservation and build-revival project for MS-DOS 4.00 —
the 1988/89 IBM/Microsoft 16-bit DOS sources. It contains the full original tree:
BIOS (IO.SYS), kernel (DOS/ MSDOS.SYS), boot sector (BOOT/MSBOOT.ASM), commands
(COMMAND.COM, FORMAT, FDISK, ATTRIB, ...), device drivers (SMARTDRV, RAMDRIVE, ANSI, ...),
the NLS mapper, MEMM/EMM managers, and the shipped 1988 16-bit toolchain
(MASM, LINK, MS C 2.x, NMAKE) under `src/TOOLS/` — MIT-licensed as released by
Microsoft/IBM.

Its purpose is to prove the sources still work: `src/build/walkthrough.sh` runs the
original DOS toolchain inside DOSBox-X on Linux, gates each phase, and produces a
bootable 720 KiB FAT12 floppy image (`build/msdos400.img`) that boots
IO.SYS → MSDOS.SYS → COMMAND.COM with utilities under `\DOS`. The build plan
(`src/build_plan.md`) is even written as an instruction set for an autonomous agent —
no human intervention needed. Per the build report, the pipeline has already succeeded:
38/38 binaries rebuilt, image gates passed, boot proof captured via serial.

In short: an OS-history project — a clean mirror of the MS-DOS 4.00 sources, plus the
proof that they compile and boot a real DOS 4.00 floppy from scratch. Not for production
use (16-bit, emulated only).

## How this repository was built

This repository was created entirely by AI — specifically **GLM-5.3-flash** — in roughly
**6 hours of work**. The agent eliminated all pitfalls and quirks in the sources
(**without reading any source code**), established the complete build pipeline, and
verified the toolchain end-to-end: the shipped 1988 toolchain was set up and
proven by running the build inside DOSBox-X until every gate passed and the
resulting floppy booted (`BOOT-OK`). No human intervention was needed at any step.

---

A clean, source-only mirror of the MS-DOS 4.00 tree — the IBM/Microsoft 1988/89 16-bit
sources. **No build intermediates, no generated images, no logs** are checked in. Only
source code and build scripts (`*.asm`, `*.inc`, `*.c`, `*.h`, Makefiles, INF/INI, `.bat`,
`.sh`, and the MS-DOS build/tuning scripts under `src/build/`).

## Prerequisites

Runs under Linux (tested with DOSBox-X 2026.01.02 + SDL2):

- `dosbox-x`
- `mtools` (`mcopy`, `mdir`, ...)
- `dosfstools` (`mkfs.fat`)
- `python3`
- `git`, `sha256sum`, `timeout`, `awk`, `stat` (used by the walkthrough gates)

Install example (Debian/Ubuntu):
`sudo apt install dosbox-x mtools dosfstools python3 git coreutils`

## Status

- **Type**: Source-preservation / study project.
- **Original copyright**: Copyright © IBM and Microsoft Corporation. Released under the
  MIT License (see `LICENSE`). The copyright notice is retained verbatim.
- **Build**: Requires the shipped 16-bit DOS toolchain (MASM, LINK, NMAKE, MS C 2.x,
  EXE2BIN, NOSRVBLD) executed inside DOSBox-X. See `src/build/README-BUILD.md` and
  `src/build_plan.md`.
- **Deliverable**: A bootable 720 KiB FAT12 floppy image (`build/msdos400.img`) — the
  reproducible output of the verified pipeline (boot sector + `IO.SYS`/`MSDOS.SYS`/
  `COMMAND.COM` + utilities).
- **Verified**: A from-scratch DOSBox-X rebuild, 38/38 binaries collected, boot proof
  via serial `BOOT-OK`. See `src/build/BUILD-REPORT.txt`.

## Contents

```
src/
├── BIOS/      IO.SYS / bios source
├── BOOT/      MSBOOT.ASM (boot sector)
├── CMD/       utilities (COMMAND.COM, ATTRIB, FORMAT, FDISK, ...)
├── DEV/       device drivers (ANSI, DISPLAY, KEYBOARD, PRINTER, RAMDRIVE, SMARTDRV, ...)
├── DOS/       MSDOS.SYS kernel
├── INC/, H/   headers and macros
├── LIB/, MESS/ shared
├── MAPPER/    NLS/ country-code mapper
├── MEMM/      XMA/EMM managers
├── SELECT/    SELECT
├── build/      scripts, reproducible pipeline, gates
└── TOOLS/     shipped 16-bit toolchain
LICENSE        MIT (IBM and Microsoft)
```

## Building

From the `src/` directory (requires `dosbox-x`, `mtools`, `mkfs.fat`, `python3`):

```bash
cd src
bash build/walkthrough.sh        # all-in-one, exit 0 == all gates passed
```

See `src/build/README-BUILD.md` for the step-by-step pipeline.

## Not for production use

These sources are 16-bit x86 and run only inside a 16-bit DOS emulation environment.
They are provided for study, build experiments, and OS-history context.

## Output of a successful build

After `bash build/walkthrough.sh` (or the manual pipeline) succeeds, the deliverable is a
**single 720 KiB FAT12 floppy image**:

```
v4.0/src/build/msdos400.img
```

The build boots via `IO.SYS` → `MSDOS.SYS` → `COMMAND.COM` and includes the utilities
under `\\DOS` (see `src/build/README-BUILD.md`).

## Running the produced image

Test the build in DOSBox-X (boots straight from the image):

```bash
dosbox-x -fda v4.0/src/build/msdos400.img
```

Or write it to a real floppy/USB:

```bash
dd if=v4.0/src/build/msdos400.img of=/dev/fd0 bs=512 status=progress
```

## Licence

MIT — original copyright notice in `LICENSE` must be retained in any copy or substantial
portion of the Software.
"