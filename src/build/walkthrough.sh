#!/usr/bin/env bash
# walkthrough.sh — one-command autonomous walkthrough of the MS-DOS 4.00 build
# (executes build_plan.md Phases 1..5 with hard gates). Writes build/BUILD-REPORT.txt.
# Exit 0 == ALL GATES PASSED (bootable 720 KiB floppy at build/msdos400.img).
# Headless-safe: uses xvfb-run when no DISPLAY is set.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRC" || exit 1
REPORT="build/BUILD-REPORT.txt"
T0=$SECONDS
: > "$REPORT"

log()  { echo "$*" | tee -a "$REPORT"; }
gate() { local s=FAIL; [ "$2" = 1 ] && s=PASS
         log "[$s] $1 ${3:-}"
         [ "$2" = 1 ] || { log "STOP — failed gate: $1 (see build_plan.md §8)"; exit 1; } }

WALKTHROUGH_INCREMENTAL="${WALKTHROUGH_INCREMENTAL:-0}"   # 1 = keep tree, build incrementally

log "== MS-DOS 4.00 build walkthrough — $(date '+%F %T') — host $(hostname) =="
log "tree: $SRC"
log "mode: WALKTHROUGH_INCREMENTAL=$WALKTHROUGH_INCREMENTAL$([ "$WALKTHROUGH_INCREMENTAL" = 1 ] && echo '  (incremental — reset-clean skipped)')"

# ---------- Phase 0: preflight (build_plan.md §1b) ----------
log "== Phase 0: preflight =="
miss=""
for t in dosbox-x mcopy mdir mtype mmd mkfs.fat python3 git sha256sum timeout awk stat; do
  command -v "$t" >/dev/null 2>&1 || miss="$miss $t"
done
if [ -z "${DISPLAY:-}" ] && ! command -v xvfb-run >/dev/null 2>&1; then
  miss="$miss xvfb-run"      # headless: DOSBox-X calls go through xvfb-run -a
fi
missf=""
for f in MASM.EXE LINK.EXE NMAKE.EXE CL.EXE EXE2BIN.EXE ASC2HLP.EXE \
         BUILDMSG.EXE BUILDIDX.EXE COMPRESS.COM BLD/LIB BLD/INC; do
  [ -e "TOOLS/$f" ] || missf="$missf TOOLS/$f"
done
for f in build/dosall.bat build/dosbox-x.conf build/boottest.conf \
         build/fix-mojibake.py build/fix-lines-80.py build/inspect-image.py \
         build/reset-clean.sh patch_bpb.py make-floppy.sh; do
  [ -e "$f" ] || missf="$missf $f"
done
gate "preflight: host tools + shipped TOOLS/ + drivers present" \
  "$([ -z "$miss$missf" ] && echo 1 || echo 0)" \
  "missing host tools:${miss:- none}; missing tree files:${missf:- none}"
log "versions: $(mcopy -V | head -1) | $(mkfs.fat --help 2>&1 | tail -1) | $(python3 --version) | $(dosbox-x -h 2>&1 | grep -im1 version)"

# ---------- Phase 1: source state ----------
log "== Phase 1: source state =="
python3 build/fix-mojibake.py . --dry-run >/tmp/rw1.txt 2>&1
if grep -q "done: 0 files modified, 0 mojibake sequences" /tmp/rw1.txt; then
  gate "mojibake-free sources" 1
else
  python3 build/fix-mojibake.py . >>"$REPORT" 2>&1
  python3 build/fix-mojibake.py . --dry-run >/tmp/rw1.txt 2>&1
  grep -q "done: 0 files modified, 0 mojibake sequences" /tmp/rw1.txt \
    && gate "mojibake fixed + re-verified clean" 1 \
    || gate "mojibake persists after auto-fix (see $REPORT)" 0
fi

n_over=$(awk '{sub(/\r$/,""); if(length($0)>80) n++} END{print n+0}' SELECT/SELECT2.ASM)
if [ "$n_over" = 0 ]; then
  gate "SELECT2.ASM within 80 cols" 1
else
  python3 build/fix-lines-80.py SELECT/SELECT2.ASM >>"$REPORT" 2>&1
  n_over=$(awk '{sub(/\r$/,""); if(length($0)>80) n++} END{print n+0}' SELECT/SELECT2.ASM)
  [ "$n_over" = 0 ] && gate "SELECT2.ASM shortened + re-verified" 1 \
    || gate "SELECT2.ASM still >80 cols after fix" 0 "remaining long lines: $n_over"
fi

cmp -s SELECT/USA.INF SELECT/PANEL.INF || cp -f SELECT/USA.INF SELECT/PANEL.INF
gate "USA.INF == PANEL.INF" 1

if python3 - <<'PY' >>"$REPORT" 2>&1
import glob, sys
FILES = (glob.glob("**/*.SKL", recursive=True)
         + ["MESSAGES/USA-MS.MSG", "BIOS/LOCSCR",
            "DEV/DISPLAY/ZERO.DAT", "DEV/PRINTER/ZERO.DAT"])

def dirty(d):
    return b"\r\n" not in d or any(l.endswith(b"\n") for l in d.split(b"\r\n")[1:])

bad = []
for f in FILES:
    try:
        data = open(f, "rb").read()
    except OSError:
        continue
    if dirty(data):
        open(f, "wb").write(data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        data = open(f, "rb").read()
        print("CRLF-restored:", f)
    if dirty(data):
        bad.append(f)
        print("STILL-BAD (not CRLF-complete):", f)
print("CRLF-BAD:", bad) if bad else print("CRLF-OK (all DOS-read files)")
sys.exit(1 if bad else 0)
PY
then gate "CRLF complete for DOS-read files" 1 "(details/repairs in $REPORT)"
else gate "CRLF still incomplete after repair" 0 "see $REPORT"
fi

[ -f MESSAGES/USA-MS.IDX ] && rm -fv MESSAGES/USA-MS.IDX >/dev/null || true

# ---------- Phase 2: the build ----------
log "== Phase 2: full build (DOSBox-X, unattended) =="
pkill -f dosbox-x 2>/dev/null; sleep 1     # enforce: one DOSBox-X process at a time
if [ "$WALKTHROUGH_INCREMENTAL" = 1 ]; then
  log "incremental: reset-clean skipped"
else
  bash build/reset-clean.sh >>"$REPORT" 2>&1 || gate "reset-clean" 0
fi
# rotate stale logs so the fatal-error gate only sees THIS run (build_plan.md §4)
mkdir -p bin build/log; rm -f build/log/M-*.TXT
timeout -k 60 7200 bash -c 'cd "$1" && ./build-msdos.sh' _ "$SRC" >>"$REPORT" 2>&1 \
  || gate "build-msdos.sh completed" 0 "rc=$? — inspect build/log/"
gate "38/38 binaries collected" "$( [ "$(ls bin | wc -l)" = 38 ] && echo 1 )"
gate "boot essentials exact" \
  "$( [ "$(stat -c %s bin/io.sys)" = 33321 ] && [ "$(stat -c %s bin/msdos.sys)" = 37376 ] && [ "$(stat -c %s bin/command.com)" = 37556 ] && echo 1 )" \
  "$(stat -c '%s %n' bin/io.sys bin/msdos.sys bin/command.com | tr '\n' ';')"
nz=$(find build/log -maxdepth 1 -iname 'm-*.txt' -size +0 | wc -l)
nlog=$(find build/log -maxdepth 1 -iname 'm-*.txt' | wc -l)
nobj=$(find . -name '*.obj' -o -name '*.OBJ' 2>/dev/null | grep -vE '\./(TOOLS|INC|LIB|H|build)/' | wc -l)
if [ "$WALKTHROUGH_INCREMENTAL" = 1 ]; then
  log "evidence (incremental, log volume not gated — build_plan.md §4): .OBJ present: $nobj | non-empty logs: $nz of $nlog"
else
  gate "clean run did real work" "$( [ "$nobj" -ge 400 ] && echo 1 )" "≈400 .OBJ regenerated: $nobj"
  gate "full rebuild evidenced in logs" "$( [ "$nz" -ge 50 ] && echo 1 )" \
    "$nz non-empty of $nlog (5 silent leaves + 1 8.3 collision are expected; LESS would be A10)"
fi
hits=$(grep -in 'error A\|error L\|fatal\|E_Exit' build/log/M-*.TXT 2>/dev/null \
      | tr '\n' ';' | cut -c1-400)
gate "no fatal errors in logs" "$([ -z "$hits" ] && echo 1 || echo 0)" "${hits:-none}"
gate "no E_Exit in console" "$( [ "$(grep -ci 'e_exit\|critical' log/dosbox-build.log)" = 0 ] && echo 1 )"

# ---------- Phase 3: floppy ----------
log "== Phase 3: floppy assembly =="
./make-floppy.sh >>"$REPORT" 2>&1 || gate "make-floppy.sh" 0
gate "image is 737,280 B" "$( [ "$(stat -c %s build/msdos400.img)" = 737280 ] && echo 1 )"
python3 build/inspect-image.py >>"$REPORT" 2>&1 && gate "inspect-image: ALL GATES" 1 \
  || { tail -6 "$REPORT"; gate "inspect-image" 0; }
SHA_PRE=$(sha256sum build/msdos400.img | cut -d' ' -f1)   # for the Phase-4 isolation check

# ---------- Phase 4: boot proof (on a copy) ----------
log "== Phase 4: boot proof (isolated copy) =="
cp -f build/msdos400.img /tmp/test.img
printf 'echo BOOT-OK > COM1\r\necho X > A:\\MARKER.TXT\r\n' > /tmp/autoexec.bat
mcopy -i /tmp/test.img -o /tmp/autoexec.bat ::AUTOEXEC.BAT
rm -f /tmp/com1.txt
cat > /tmp/bt.conf <<'EOF'
[sdl]
output=dummy
[dosbox]
machine=cga
memsize=16
output=dummy
[cpu]
cputype=486
cycles=max
[serial]
serial1=file file:/tmp/com1.txt timeout:1000
[autoexec]
imgmount a /tmp/test.img -t floppy
boot a:
EOF
XWRAP=""; [ -n "${DISPLAY:-}" ] || XWRAP="xvfb-run -a"     # headless-safe
timeout 120 $XWRAP dosbox-x -conf /tmp/bt.conf -nogui -nomenu -time-limit 35 >>"$REPORT" 2>&1
grep -q BOOT-OK /tmp/com1.txt 2>/dev/null && gate "PROOF1 serial BOOT-OK" 1 || gate "PROOF1 serial BOOT-OK" 0
# NOTE: mdir pads 8.3 names ("MARKER   TXT") — match 'MARKER', not 'MARKER.TXT'
mdir -i /tmp/test.img :: | grep -qi MARKER && gate "PROOF2 write-back MARKER.TXT" 1 \
  || gate "PROOF2 write-back MARKER.TXT" 0
[ "$(sha256sum build/msdos400.img | cut -d' ' -f1)" = "$SHA_PRE" ] \
  && gate "deliverable untouched by boot test" 1 || gate "deliverable untouched by boot test" 0

# ---------- Phase 5: deliver ----------
log "== Phase 5: deliver =="
sha256sum build/msdos400.img | tee build/msdos400.img.sha256 | tee -a "$REPORT"
mdir -i build/msdos400.img :: | head -9 | tee -a "$REPORT"
rm -f /tmp/test.img /tmp/autoexec.bat /tmp/com1.txt /tmp/bt.conf /tmp/rw1.txt

log "== wall time: $((SECONDS-T0)) s — see $REPORT =="
grep -c '\[PASS\]' "$REPORT" | sed 's/^/gates passed: /' | tee -a "$REPORT"
exit 0