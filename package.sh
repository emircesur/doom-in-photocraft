#!/usr/bin/env bash
# Builds the release: doom-in-photocraft-<version>.zip (the PhotoCraft plug-in, its actions
# for the keys, the licences and how to play), and the plug-in and actions on their own for the
# install scripts. The same sources give the same files.
#
#   ./package.sh OUT_DIR
#
# Needs clang and wasm-ld (any recent LLVM), curl, python3.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.1"
FREEDOOM_URL="https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip"
FREEDOOM_SHA256="3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
WORK="$OUT/work"
mkdir -p "$WORK"

if [ ! -f "$WORK/freedoom.zip" ]; then
  curl -fsSL -o "$WORK/freedoom.zip" "$FREEDOOM_URL"
fi
echo "$FREEDOOM_SHA256  $WORK/freedoom.zip" | sha256sum -c -
python3 - "$WORK/freedoom.zip" "$WORK" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for name in ("freedoom-0.13.0/freedoom1.wad", "freedoom-0.13.0/COPYING.txt"):
        open(f"{sys.argv[2]}/{name.split('/')[1]}", "wb").write(z.read(name))
PY
python3 "$HERE/wad/strip_wad.py" "$WORK/freedoom1.wad" "$WORK/freedoom1-e1.wad"
"$HERE/build.sh" "$WORK/freedoom1-e1.wad" "$WORK" photocraft

python3 - "$OUT/doom-in-photocraft-$VERSION.zip" <<PY
import sys, zipfile
files = [
    ("doom-photocraft.wasm", "$WORK/doom-photocraft.wasm"),
    ("doom-actions.json", "$HERE/photocraft/doom-actions.json"),
    ("README.txt", "$HERE/photocraft/README.txt"),
    ("LICENSE-doomgeneric.txt", "$HERE/doomgeneric/LICENSE"),
    ("LICENSE-freedoom.txt", "$WORK/COPYING.txt"),
]
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for name, path in files:
        info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        z.writestr(info, open(path, "rb").read())
PY
cp "$WORK/doom-photocraft.wasm" "$HERE/photocraft/doom-actions.json" "$OUT/"
(cd "$OUT" && sha256sum "doom-in-photocraft-$VERSION.zip" doom-photocraft.wasm doom-actions.json | tee SHA256SUMS.txt)
