#!/usr/bin/env bash
# Remote command lines are built client-side on purpose (args quoted with printf %q).
# shellcheck disable=SC2029
# deploy.sh - push the Inference-reader setup (plugin + patch + prompts + settings +
# papers) to an Android phone running KOReader, from a fresh clone of this repo.
#
#   inference-reader/tools/deploy.sh --dry-run      # show what would happen, touch nothing
#   inference-reader/tools/deploy.sh                # deploy via VM117 (adb over ssh)
#   inference-reader/tools/deploy.sh --local        # deploy with the adb on this machine
#
# Settings come from (later wins): built-in defaults < inference-reader/local.env
# (gitignored; or $KR_ENV_FILE) < environment < command-line flags.
# The API key is read from PROXY_API_KEY / PROXY_API_KEY_FILE (or --key-from-pi) and
# is never printed. See inference-reader/README.md.
set -euo pipefail

TOOLS=$(cd "$(dirname "$0")" && pwd)
KIT=$(dirname "$TOOLS")
REPO=$(dirname "$KIT")

usage() {
  cat <<'EOF'
Usage: deploy.sh [options]
  --dry-run            print device/ssh commands instead of running them (no phone access)
  --local              run adb on this machine (default: over ssh on $KR_SSH)
  --ssh HOST           ssh target that has adb        (env KR_SSH, default ubuntu@192.168.50.179)
  --adb PATH           adb binary                     (env KR_ADB, default /opt/android-sdk/platform-tools/adb,
                                                       or `adb` with --local)
  --serial SERIAL      adb device serial              (env KR_SERIAL)
  --papers-dir DIR     paper cache                    (env KR_PAPERS_DIR, default inference-reader/.cache/papers)
  --no-papers          skip downloading/pushing PDFs
  --key-from-pi        take the key from ~/.pi/agent/extensions/proxycli.ts if PROXY_API_KEY is unset
  --install-koreader   also install KOReader v2026.07.1 arm64 (APK from GitHub releases)
  --bookinfo           also apply overrides/bookinfo_cache.sql to the coverbrowser DB
  --reset-history      also reset koreader/history.lua to {}
  --start              start KOReader when done
  -h, --help           this text
Env for the config: PROXY_API_KEY | PROXY_API_KEY_FILE, PROXY_LAN_URL, PROXY_TS_URL, PROXY_MODEL
EOF
}

ENV_FILE=${KR_ENV_FILE:-$KIT/local.env}
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

DRY=0 LOCAL=0 PAPERS=1 KEY_FROM_PI=0 INSTALL_KO=0 BOOKINFO=0 RESET_HISTORY=0 START=0
SSH_HOST=${KR_SSH:-ubuntu@192.168.50.179}
ADB=${KR_ADB:-}
SERIAL=${KR_SERIAL:-adb-4A291FDKD000WL-B4mSIf._adb-tls-connect._tcp}
PAPERS_DIR=${KR_PAPERS_DIR:-$KIT/.cache/papers}
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY=1 ;;
    --local) LOCAL=1 ;;
    --ssh) SSH_HOST=$2; shift ;;
    --adb) ADB=$2; shift ;;
    --serial) SERIAL=$2; shift ;;
    --papers-dir) PAPERS_DIR=$2; shift ;;
    --no-papers) PAPERS=0 ;;
    --key-from-pi) KEY_FROM_PI=1 ;;
    --install-koreader) INSTALL_KO=1 ;;
    --bookinfo) BOOKINFO=1 ;;
    --reset-history) RESET_HISTORY=1 ;;
    --start) START=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
if [[ -z "$ADB" ]]; then
  if [[ $LOCAL -eq 1 ]]; then ADB=adb; else ADB=/opt/android-sdk/platform-tools/adb; fi
fi

PKG=org.koreader.launcher
KO_VERSION=v2026.07.1
APK_URL=https://github.com/koreader/koreader/releases/download/$KO_VERSION/koreader-android-arm64-$KO_VERSION.apk
K=/sdcard/koreader
KS=/storage/emulated/0/koreader   # path KOReader writes into settings headers
PLUGIN=$K/plugins/assistant.koplugin

for t in luajit python3; do
  command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
done

W=$(mktemp -d); chmod 700 "$W"; trap 'rm -rf "$W"' EXIT
STAGE=$W/stage

# --- transport -------------------------------------------------------------
q() { printf '%q ' "$@"; }
# remote: run a command line on the adb host (ssh) or locally
host() {
  if [[ $DRY -eq 1 ]]; then
    if [[ $LOCAL -eq 1 ]]; then echo "[dry-run] $*"; else echo "[dry-run] ssh $SSH_HOST $*"; fi
    return 0
  fi
  if [[ $LOCAL -eq 1 ]]; then bash -c "$*"; else ssh "$SSH_HOST" "$*"; fi
}
adb_() { host "$(q "$ADB" -s "$SERIAL" "$@")"; }
devsh() { adb_ shell "$1"; }                 # one shell command line on the phone
pull() {                                      # pull <device-path> <local-file>
  if [[ $DRY -eq 1 ]]; then echo "[dry-run] pull $1"; : > "$2"; return 0; fi
  if [[ $LOCAL -eq 1 ]]; then "$ADB" -s "$SERIAL" exec-out cat "$1" > "$2" 2>/dev/null || : > "$2"
  else ssh "$SSH_HOST" "$(q "$ADB" -s "$SERIAL" exec-out cat "$1") 2>/dev/null" > "$2" || : > "$2"; fi
}
# push <local-dir> <device-dir>: copy the CONTENTS of local-dir into device-dir;
# push <local-file> <device-path>: copy one file. Over ssh the data goes through a
# private (0700) temp dir on the adb host that is removed right after the push.
push() {
  local src=$1 dst=$2 rel
  rel=$(basename "$src"); [[ -d "$src" ]] && rel=$rel/.
  if [[ $DRY -eq 1 ]]; then echo "[dry-run] push $src -> $dst"; return 0; fi
  if [[ $LOCAL -eq 1 ]]; then
    if [[ -d "$src" ]]; then "$ADB" -s "$SERIAL" push "$src/." "$dst" >/dev/null
    else "$ADB" -s "$SERIAL" push "$src" "$dst" >/dev/null; fi
    return
  fi
  local rt; rt=$(ssh "$SSH_HOST" 'umask 077; mktemp -d /tmp/kpx-stage.XXXXXX')
  scp -qr "$src" "$SSH_HOST:$rt/"
  ssh "$SSH_HOST" "$(q "$ADB" -s "$SERIAL" push "$rt/$rel" "$dst") >/dev/null; rc=\$?; rm -rf $(q "$rt"); exit \$rc"
}

echo "== target: $([[ $LOCAL -eq 1 ]] && echo local || echo "ssh $SSH_HOST") adb=$ADB serial=$SERIAL$([[ $DRY -eq 1 ]] && echo ' (dry run)')"

# --- 1. papers (local, before touching the phone) ---------------------------
if [[ $PAPERS -eq 1 ]]; then
  echo "== papers -> $PAPERS_DIR"
  "$TOOLS/fetch-papers.sh" "$PAPERS_DIR"
fi

# --- 2. render configuration.lua (key never printed) ------------------------
echo "== render configuration.lua"
mkdir -p "$STAGE/koreader/plugins" "$STAGE/koreader/settings" "$STAGE/koreader/patches" "$STAGE/Books"
rsync -a --exclude .git --exclude .github --exclude inference-reader --exclude test \
  --exclude configuration.lua --exclude apikeys.lua --exclude .DS_Store \
  "$REPO/" "$STAGE/koreader/plugins/assistant.koplugin/"
CFG=$STAGE/koreader/plugins/assistant.koplugin/configuration.lua
PI_FLAG=(); [[ $KEY_FROM_PI -eq 1 ]] && PI_FLAG=(--key-from-pi)
if [[ $DRY -eq 1 ]]; then
  python3 "$TOOLS/render-config.py" --placeholder "$CFG"
  ( if python3 "$TOOLS/render-config.py" "${PI_FLAG[@]}" "$W/keycheck.lua" >/dev/null 2>&1
    then echo "   key: found (not printed)"; else echo "   key: MISSING - a real deploy would stop here"; fi
    rm -f "$W/keycheck.lua" )
else
  python3 "$TOOLS/render-config.py" "${PI_FLAG[@]}" "$CFG"
fi
F=$CFG luajit -e "local c = dofile(os.getenv('F')); assert(c.features.prompts.explain_page and c.provider_settings.openai_proxycli_lan)"

# --- 3. library (papers + metadata + cheat sheet) ---------------------------
cp -R "$KIT/library/Books/Inference" "$STAGE/Books/"
if [[ $PAPERS -eq 1 ]]; then
  cp -R "$PAPERS_DIR/." "$STAGE/Books/Inference/"
  find "$STAGE/Books/Inference" -name '*.part' -delete
  python3 "$TOOLS/make-metadata.py" "$PAPERS_DIR" "$STAGE/Books/Inference" >/dev/null
fi
cp "$KIT"/koreader/patches/*.lua "$STAGE/koreader/patches/"

# --- 4. phone: stop KOReader, back up ---------------------------------------
if [[ $INSTALL_KO -eq 1 ]]; then
  echo "== install KOReader $KO_VERSION"
  apk=$KIT/.cache/koreader-android-arm64-$KO_VERSION.apk
  if [[ $DRY -eq 0 && ! -s "$apk" ]]; then mkdir -p "$KIT/.cache"; curl -fsSL -o "$apk" "$APK_URL"; fi
  if [[ $DRY -eq 1 ]]; then echo "[dry-run] download $APK_URL; adb install -r"
  elif [[ $LOCAL -eq 1 ]]; then "$ADB" -s "$SERIAL" install -r "$apk"
  else
    scp -q "$apk" "$SSH_HOST:/tmp/koreader.apk"
    ssh "$SSH_HOST" "$(q "$ADB" -s "$SERIAL" install -r /tmp/koreader.apk); rc=\$?; rm -f /tmp/koreader.apk; exit \$rc"
  fi
fi

echo "== stop KOReader (it rewrites settings on exit)"
devsh "am force-stop $PKG"
BK=$K/backup-$(date +%F-%H%M%S)
echo "== backup on the phone -> $BK"
devsh "mkdir -p $BK/plugin && for f in settings.reader.lua history.lua; do [ -f $K/\$f ] && cp $K/\$f $BK/; done; [ -d $K/settings ] && cp -r $K/settings $BK/; [ -d $K/patches ] && cp -r $K/patches $BK/; for f in main.lua configuration.lua feature/inference_reader.lua; do [ -f $PLUGIN/\$f ] && cp $PLUGIN/\$f $BK/plugin/; done; echo backup: $BK"

# --- 5. merge settings on top of the phone's current files ------------------
echo "== merge settings"
merge() { # merge <device-file> <override> <stage-out>
  local cur
  cur=$W/cur.$(basename "$1")
  pull "$1" "$cur"
  if [[ -s "$cur" ]] && ! F=$cur luajit -e "assert(type(dofile(os.getenv('F'))) == 'table')" 2>/dev/null; then
    echo "cannot parse $1 from the phone; refusing to overwrite it" >&2; exit 1
  fi
  [[ -s "$cur" ]] || cur=/nonexistent
  luajit "$TOOLS/kosettings.lua" "$cur" "$2" "$3" "${1/#$K/$KS}"
}
merge $K/settings.reader.lua  "$KIT/overrides/settings.reader.lua" "$STAGE/koreader/settings.reader.lua"
merge $K/settings/gestures.lua  "$KIT/overrides/gestures.lua"      "$STAGE/koreader/settings/gestures.lua"
merge $K/settings/assistant.lua "$KIT/overrides/assistant.lua"     "$STAGE/koreader/settings/assistant.lua"
luajit "$TOOLS/kosettings.lua" /nonexistent "$KIT/overrides/collection.lua" "$STAGE/koreader/settings/collection.lua" "$KS/settings/collection.lua"
if [[ $RESET_HISTORY -eq 1 ]]; then
  printf -- '-- %s/history.lua\nreturn {}\n' "$KS" > "$STAGE/koreader/history.lua"
fi

# --- 6. push ----------------------------------------------------------------
echo "== push"
devsh "mkdir -p $K /sdcard/Books"
push "$STAGE/koreader" "$K/"
push "$STAGE/Books" /sdcard/Books/
echo "   pushed: $(find "$STAGE" -type f | wc -l | tr -d ' ') files"

# --- 7. optional: coverbrowser DB (files per page etc.) ---------------------
if [[ $BOOKINFO -eq 1 ]]; then
  echo "== bookinfo_cache.sqlite3"
  command -v sqlite3 >/dev/null || { echo "missing tool: sqlite3" >&2; exit 1; }
  DB=$K/settings/bookinfo_cache.sqlite3
  for s in "" -wal -shm; do pull "$DB$s" "$W/bookinfo_cache.sqlite3$s"; done
  if [[ $DRY -eq 1 ]]; then
    echo "[dry-run] sqlite3 < overrides/bookinfo_cache.sql; push $DB; rm $DB-wal $DB-shm"
  elif [[ ! -s "$W/bookinfo_cache.sqlite3" ]]; then
    echo "   no DB on the phone yet (open the library once, then rerun with --bookinfo)"
  else
    for s in -wal -shm; do [[ -s "$W/bookinfo_cache.sqlite3$s" ]] || rm -f "$W/bookinfo_cache.sqlite3$s"; done
    sqlite3 "$W/bookinfo_cache.sqlite3" < "$KIT/overrides/bookinfo_cache.sql"
    sqlite3 "$W/bookinfo_cache.sqlite3" 'PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;' >/dev/null
    push "$W/bookinfo_cache.sqlite3" "$DB"
    devsh "rm -f $DB-wal $DB-shm"
  fi
fi

if [[ $START -eq 1 ]]; then devsh "am start -n $PKG/.MainActivity"; fi
echo "== done$([[ $DRY -eq 1 ]] && echo ' (dry run: nothing was sent to the phone)')"
[[ $START -eq 1 ]] || echo "   start KOReader on the phone (or rerun with --start)"
