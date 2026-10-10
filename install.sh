#!/bin/sh
# Installs Doom in PhotoCraft (Linux and macOS), without CraftSpace:
#
#   curl -fsSL https://raw.githubusercontent.com/emircesur/doom-in-photocraft/main/install.sh | sh
#
# Options: --uninstall           take it out again
#          --config DIR          PhotoCraft's settings folder (a portable copy's data folder)
#          --from DIR            use doom-photocraft.wasm and doom-actions.json from DIR
#
# It puts the plug-in in PhotoCraft's additional plug-ins folder (Preferences › Plug-ins; set to
# <settings>/Plug-ins if none is set), adds the "Doom: …" actions to the Actions panel and binds
# Alt+Shift keys to them (keys you already use are left alone). Close PhotoCraft first.
set -eu

REPO="emircesur/doom-in-photocraft"
BASE="https://github.com/$REPO/releases/latest/download"
mode=install
config="${PHOTOCRAFT_CONFIG_DIR:-}"
from=""
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) mode=uninstall ;;
    --config) config="$2"; shift ;;
    --from) from="$2"; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

os="$(uname -s)"
if [ -z "$config" ]; then
  case "$os" in
    Darwin) config="$HOME/Library/Application Support/Photocraft" ;;
    *) config="${XDG_CONFIG_HOME:-$HOME/.config}/photocraft" ;;
  esac
fi

if pgrep -x photocraft >/dev/null 2>&1 || pgrep -x PhotoCraft >/dev/null 2>&1; then
  echo "PhotoCraft is open. Close it first (it saves its actions and preferences when it quits)." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

if [ "$mode" = install ]; then
  if [ -n "$from" ]; then
    cp "$from/doom-photocraft.wasm" "$from/doom-actions.json" "$tmp/"
  else
    fetch() {
      if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$tmp/$1" "$BASE/$1"
      else wget -q -O "$tmp/$1" "$BASE/$1"; fi
    }
    echo "Downloading Doom in PhotoCraft…"
    fetch doom-photocraft.wasm
    fetch doom-actions.json
    fetch SHA256SUMS.txt
    (
      cd "$tmp"
      grep -E ' (doom-photocraft\.wasm|doom-actions\.json)$' SHA256SUMS.txt >sums
      if command -v sha256sum >/dev/null 2>&1; then sha256sum -c sums >/dev/null
      else shasum -a 256 -c sums >/dev/null; fi
    ) || { echo "The download doesn't match its checksum; not installing." >&2; exit 1; }
  fi
fi

mkdir -p "$config/Presets"

if [ "$os" = Darwin ]; then
  # macOS: JavaScript for Automation is always there (python3 may not be). It only edits the two
  # JSON files and prints the plug-ins folder; the shell moves the plug-in itself.
  out="$(osascript -l JavaScript - "$mode" "$config" "$tmp" <<'JXA'
ObjC.import("Foundation");
function run(argv) {
  var mode = argv[0], config = argv[1], tmp = argv[2];
  function read(path) {
    var s = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, $());
    return s.isNil() ? null : JSON.parse(ObjC.unwrap(s));
  }
  function write(path, value) {
    var ok = $(JSON.stringify(value, null, 2) + "\n").writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, $());
    if (!ok) throw new Error("can't write " + path);
  }
  var prefsPath = config + "/preferences.json", actionsPath = config + "/Presets/actions.json";
  var prefs = read(prefsPath) || {};
  var list = read(actionsPath) || { version: 1, actions: [] };
  if (list.version !== 1) throw new Error("PhotoCraft's actions.json is a newer version than this installer knows.");
  var add = mode === "install" ? read(tmp + "/doom-actions.json") : null;
  var names = mode === "install"
    ? add.actions.map(function (a) { return a.name; })
    : list.actions.map(function (a) { return a.name || ""; }).filter(function (n) { return n.indexOf("Doom: ") === 0; });
  prefs.plugIns = prefs.plugIns || {};
  var folder = (prefs.plugIns.useAdditionalPluginsFolder && prefs.plugIns.additionalPluginsFolder) || "";
  list.actions = list.actions.filter(function (a) { return names.indexOf(a.name) < 0; });
  prefs.shortcuts = prefs.shortcuts || {};
  names.forEach(function (n) { delete prefs.shortcuts["actions.play:" + n]; });
  var note = "";
  if (mode === "install") {
    if (!folder) {
      folder = config + "/Plug-ins";
      prefs.plugIns.useAdditionalPluginsFolder = true;
      prefs.plugIns.additionalPluginsFolder = folder;
    }
    list.actions = list.actions.concat(add.actions);
    var taken = [];
    Object.keys(add.shortcuts).forEach(function (n) {
      var key = add.shortcuts[n], id = "actions.play:" + n;
      var used = Object.keys(prefs.shortcuts).some(function (k) { return k !== id && prefs.shortcuts[k] === key; });
      if (used) taken.push(key); else prefs.shortcuts[id] = key;
    });
    if (taken.length) note = " (keys already used, left alone: " + taken.join(", ") + ")";
  }
  write(actionsPath, list);
  write(prefsPath, prefs);
  return folder + "\n" + names.length + "\n" + note;
}
JXA
)"
  folder="$(printf '%s\n' "$out" | sed -n 1p)"
  count="$(printf '%s\n' "$out" | sed -n 2p)"
  note="$(printf '%s\n' "$out" | sed -n 3p)"
  if [ "$mode" = install ]; then
    mkdir -p "$folder"
    cp "$tmp/doom-photocraft.wasm" "$folder/doom-photocraft.wasm"
    echo "Installed: the plug-in is in $folder, and $count Doom actions are in the Actions panel$note."
  else
    [ -n "$folder" ] && rm -f "$folder/doom-photocraft.wasm"
    echo "Removed Doom ($count actions)."
  fi
else
  command -v python3 >/dev/null 2>&1 || { echo "python3 is needed to edit PhotoCraft's settings." >&2; exit 1; }
  python3 - "$mode" "$config" "$tmp" <<'PY'
import json, os, shutil, sys

mode, config, tmp = sys.argv[1:4]
prefs_path = os.path.join(config, "preferences.json")
actions_path = os.path.join(config, "Presets", "actions.json")

def read(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default

def write(path, value):
    tmp_path = path + ".new"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, path)

prefs = read(prefs_path, {})
actions = read(actions_path, {"version": 1, "actions": []})
if actions.get("version") != 1:
    sys.exit("PhotoCraft's actions.json is a newer version than this installer knows.")
add = read(os.path.join(tmp, "doom-actions.json"), None) if mode == "install" else None
if mode == "install":
    names = [a["name"] for a in add["actions"]]
else:
    names = [a["name"] for a in actions["actions"] if a.get("name", "").startswith("Doom: ")]
plugins = prefs.setdefault("plugIns", {})
folder = plugins.get("additionalPluginsFolder") if plugins.get("useAdditionalPluginsFolder") else None
actions["actions"] = [a for a in actions["actions"] if a.get("name") not in names]
shortcuts = prefs.setdefault("shortcuts", {})
for n in names:
    shortcuts.pop("actions.play:" + n, None)

if mode == "install":
    if not folder:
        folder = os.path.join(config, "Plug-ins")
        plugins["useAdditionalPluginsFolder"] = True
        plugins["additionalPluginsFolder"] = folder
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(os.path.join(tmp, "doom-photocraft.wasm"), os.path.join(folder, "doom-photocraft.wasm"))
    actions["actions"] += add["actions"]
    taken = []
    for n, key in add["shortcuts"].items():
        sid = "actions.play:" + n
        if any(k != sid and v == key for k, v in shortcuts.items()):
            taken.append(key)
        else:
            shortcuts[sid] = key
    write(actions_path, actions)
    write(prefs_path, prefs)
    print(f"Installed: the plug-in is in {folder}, and {len(names)} Doom actions are in the Actions panel"
          + (f" (keys already used, left alone: {', '.join(taken)})" if taken else "") + ".")
else:
    if folder:
        try:
            os.remove(os.path.join(folder, "doom-photocraft.wasm"))
        except FileNotFoundError:
            pass
    write(actions_path, actions)
    write(prefs_path, prefs)
    print(f"Removed Doom ({len(names)} actions).")
PY
fi

if [ "$mode" = install ]; then
  echo "Start PhotoCraft, make a new 640 x 400 RGB document and double-click a Doom move in Window > Actions (newer PhotoCraft versions also play them with Alt+Shift+W, A, S, D)."
fi
