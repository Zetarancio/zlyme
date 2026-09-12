#!/bin/sh
# Overlays.pak - browse, preview and install community overlays for NextUI
# Source: https://github.com/LoveRetro/nextui-community-overlays
# Pak conventions: https://github.com/LoveRetro/NextUI/blob/main/PAKS.md

PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"

cd "$PAK_DIR" || exit 1

# Logging
mkdir -p "$LOGS_PATH" 2>/dev/null
LOG_FILE="${LOGS_PATH:-/tmp}/$PAK_NAME.txt"
rm -f "$LOG_FILE"
exec >>"$LOG_FILE" 2>&1
echo "$(date) launch: $0 $*"
set -x

# Architecture (some platforms ship arm + arm64 binaries side-by-side)
ARCH="arm"
if uname -m | grep -q '64'; then
  ARCH="arm64"
fi

# Persistent storage for downloaded helpers / settings
export HOME="${SHARED_USERDATA_PATH:-/tmp}/$PAK_NAME"
mkdir -p "$HOME/bin" "$HOME/cache"

# Add bundled and persisted helper directories to PATH
export PATH="$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin/$ARCH:$PAK_DIR/bin/shared:$HOME/bin:$PATH"

# Working dir for transient artifacts (tree.json, preview images)
WORK_DIR="$(mktemp -d 2>/dev/null || echo "/tmp/${PAK_NAME}.$$")"
mkdir -p "$WORK_DIR"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
# Without an explicit exit, POSIX sh resumes the loop after the trap fires,
# which is why a system shutdown was bouncing back into the pak menu.
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM HUP

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

REPO_USER="LoveRetro"
REPO_NAME="nextui-community-overlays"
REPO_BRANCH="main"

# Many handhelds (Trimui Brick, etc.) ship without a CA bundle, so curl can't
# verify any HTTPS endpoint. The data we pull is public and pinned to known
# hosts (api.github.com, raw.githubusercontent.com, github.com releases), so
# the practical risk of skipping verification is minimal. If a CA bundle is
# present we still prefer it.
CURL="curl -fsSL --connect-timeout 15 --max-time 180"
for ca in /etc/ssl/certs/ca-certificates.crt \
          /etc/pki/tls/certs/ca-bundle.crt \
          /etc/ssl/cert.pem; do
  if [ -f "$ca" ]; then
    CURL="$CURL --cacert $ca"
    HAS_CA=1
    break
  fi
done
if [ -z "$HAS_CA" ]; then
  CURL="$CURL --insecure"
fi

TREE_API="https://api.github.com/repos/${REPO_USER}/${REPO_NAME}/git/trees/${REPO_BRANCH}?recursive=1"
RAW_BASE="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

MINUI_LIST_RELEASE="https://github.com/josegonzalez/minui-list/releases/latest/download"
MINUI_PRES_RELEASE="https://github.com/josegonzalez/minui-presenter/releases/latest/download"

# Where overlays are installed for libretro cores. NextUI reads
# /Overlays/[CORE]/*.png  (some forks support /Overlays/[res]/[CORE]/*).
OVERLAYS_ROOT="${SDCARD_PATH:-/mnt/SDCARD}/Overlays"

# ---------------------------------------------------------------------------
# Platform/resolution detection
# ---------------------------------------------------------------------------

# Map NextUI's $PLATFORM (and optional $DEVICE) into:
#   - REPO_RES: which resolution folder of the overlays repo to look at
#   - MINUI_BIN_TAG: which prebuilt binary suffix to pull from josegonzalez releases
detect_platform() {
  PLAT="${PLATFORM:-}"
  DEV="${DEVICE:-}"

  case "$PLAT" in
    tg5040)
      # TrimUI Smart Pro = 720p; Brick (DEVICE=brick) = 768p
      if [ "$DEV" = "brick" ]; then
        REPO_RES="768p"
      else
        REPO_RES="720p"
      fi
      MINUI_BIN_TAG="tg5040"
      ;;
    tg3040)
      REPO_RES="768p"
      MINUI_BIN_TAG="tg5040"
      ;;
    tg5050)
      REPO_RES="768p"
      MINUI_BIN_TAG="tg5050"
      ;;
    rg35xxplus)
      case "$DEV" in
        hdmi) REPO_RES="720p" ;;
        *)    REPO_RES="480p" ;;
      esac
      MINUI_BIN_TAG="rg35xxplus"
      ;;
    rg35xx)         REPO_RES="480p"; MINUI_BIN_TAG="rg35xx" ;;
    rgb30)          REPO_RES="480p"; MINUI_BIN_TAG="rgb30" ;;
    my282|miyoomini) REPO_RES="480p"; MINUI_BIN_TAG="${PLAT}" ;;
    my355)          REPO_RES="480p"; MINUI_BIN_TAG="my355" ;;
    magicmini)      REPO_RES="480p"; MINUI_BIN_TAG="magicmini" ;;
    trimui|trimuismart) REPO_RES="480p"; MINUI_BIN_TAG="trimuismart" ;;
    zero28)         REPO_RES="480p"; MINUI_BIN_TAG="zero28" ;;
    m17)            REPO_RES="720p"; MINUI_BIN_TAG="m17" ;;
    *)
      # Unknown platform - default to 720p which has the largest catalog
      REPO_RES="720p"
      MINUI_BIN_TAG="${PLAT:-tg5040}"
      ;;
  esac

  echo "Detected PLATFORM=$PLAT DEVICE=$DEV -> resolution=$REPO_RES bin=$MINUI_BIN_TAG"
}

# ---------------------------------------------------------------------------
# Helper-binary bootstrap (minui-list, minui-presenter)
# ---------------------------------------------------------------------------

ensure_minui_binary() {
  bin_name="$1"      # minui-list or minui-presenter
  release_base="$2"  # release URL prefix

  if command -v "$bin_name" >/dev/null 2>&1; then
    return 0
  fi

  local_target="$HOME/bin/$bin_name"
  if [ -x "$local_target" ]; then
    return 0
  fi

  # Try to download a prebuilt for our platform tag
  url="${release_base}/${bin_name}-${MINUI_BIN_TAG}"
  echo "Fetching $bin_name from $url"
  if $CURL -o "$local_target.tmp" "$url"; then
    chmod +x "$local_target.tmp"
    mv "$local_target.tmp" "$local_target"
    return 0
  fi

  rm -f "$local_target.tmp"
  echo "Failed to fetch $bin_name for tag $MINUI_BIN_TAG"
  return 1
}

ensure_helpers() {
  ensure_minui_binary minui-list      "$MINUI_LIST_RELEASE" || HELPERS_OK=0
  ensure_minui_binary minui-presenter "$MINUI_PRES_RELEASE" || HELPERS_OK=0
  HELPERS_OK="${HELPERS_OK:-1}"
  return 0
}

# ---------------------------------------------------------------------------
# UI wrappers
# ---------------------------------------------------------------------------

# Single global output sink for show_list. We deliberately avoid command
# substitution ($(show_list ...)) because POSIX runs that in a subshell, which
# means any variable a function sets - including the helper's exit code -
# vanishes the moment the subshell ends. Instead the function writes its
# selection to LIST_OUT_FILE and the caller cats that, while $? carries the
# real exit code straight back.
LIST_OUT_FILE="$WORK_DIR/list.out"

show_list() {
  title="$1"
  items_file="$2"
  confirm_text="${3:-SELECT}"
  cancel_text="${4:-BACK}"

  : >"$LIST_OUT_FILE"

  if [ "$HELPERS_OK" = "1" ] && command -v minui-list >/dev/null 2>&1; then
    minui-list \
      --format text \
      --file "$items_file" \
      --title "$title" \
      --confirm-text "$confirm_text" \
      --cancel-text "$cancel_text" \
      --write-location "$LIST_OUT_FILE"
    return $?
  else
    # Plain-tty fallback so the script is at least scriptable from SSH
    echo "[$title]" >&2
    nl -ba "$items_file" >&2
    printf "Pick a number (empty = back): " >&2
    read -r pick
    if [ -z "$pick" ]; then
      return 2
    fi
    sed -n "${pick}p" "$items_file" >"$LIST_OUT_FILE"
    return 0
  fi
}

# Map an exit code from a helper into one of three actions.
# Sets HELPER_ACTION to: ok | back | abort
# `abort` covers everything that is not a successful select / back press
# (segfault, kill, sigint/sigterm, etc.) - the caller should `exit "$rc"`.
classify_helper_rc() {
  rc="$1"
  case "$rc" in
    0|4) HELPER_ACTION=ok ;;
    2|3) HELPER_ACTION=back ;;
    130|143|124) HELPER_ACTION=abort ;;
    *)
      if [ "$rc" -ge 128 ] 2>/dev/null; then
        HELPER_ACTION=abort
      else
        HELPER_ACTION=back
      fi
      ;;
  esac
}

# Show a single message screen. $MSG_RC holds exit code.
show_message() {
  msg="$1"
  timeout="${2:-0}"
  if [ "$HELPERS_OK" = "1" ] && command -v minui-presenter >/dev/null 2>&1; then
    minui-presenter \
      --message "$msg" \
      --message-alignment middle \
      --confirm-button A --confirm-text "OK" --confirm-show \
      --timeout "$timeout"
    MSG_RC=$?
  else
    echo "[message] $msg"
    MSG_RC=0
  fi
  return 0
}

# Fullscreen preview of an image. Returns:
#   0   -> user pressed A (INSTALL)
#   2   -> user pressed B (BACK)
#   130/143/>=128 -> shutdown / crash / etc. (caller should propagate)
# We deliberately keep A as the *confirm* button rather than wiring it as an
# extra action button. minui-presenter rejects A being assigned twice (default
# confirm-button=A, default action-button=none); the previous version sent
# both --confirm + --action on A and minui-presenter exited 1 immediately,
# producing the "black flash, back to list" behaviour.
show_preview() {
  img_path="$1"
  caption="$2"

  ls -l "$img_path" 2>&1 || true
  if command -v file >/dev/null 2>&1; then
    file "$img_path" 2>&1 || true
  fi

  if [ "$HELPERS_OK" = "1" ] && command -v minui-presenter >/dev/null 2>&1; then
    json_file="$WORK_DIR/preview.json"
    safe_caption=$(echo "$caption" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    # Caption at the top so the bottom A/B button hints stay readable.
    cat > "$json_file" <<EOF
{
  "items": [
    {
      "text": "${safe_caption}",
      "background_image": "${img_path}",
      "alignment": "top",
      "show_pill": true
    }
  ]
}
EOF

    minui-presenter \
      --file "$json_file" \
      --confirm-button A --confirm-text "INSTALL" --confirm-show \
      --cancel-button  B --cancel-text  "BACK"    --cancel-show \
      --timeout 0
    return $?
  fi

  echo "[preview] $caption -> $img_path"
  printf "Install? (y/N): "
  read -r ans
  case "$ans" in y|Y) return 0 ;; *) return 2 ;; esac
}

# ---------------------------------------------------------------------------
# GitHub tree fetch + parsing
# ---------------------------------------------------------------------------

TREE_FILE="$WORK_DIR/tree.json"
PATHS_FILE="$WORK_DIR/paths.txt"

fetch_tree() {
  echo "Fetching repository tree..."
  if ! $CURL -H "Accept: application/vnd.github.v3+json" \
              -o "$TREE_FILE" "$TREE_API"; then
    return 1
  fi

  # Extract every blob path. The API returns one object per node, comma-separated.
  # We split on commas and grep "path" + "blob" pairs in order, then keep blobs.
  # Simpler: just grab every path; prune obviously-not-overlay paths later.
  tr ',' '\n' <"$TREE_FILE" \
    | grep -oE '"path": *"[^"]+"' \
    | sed -E 's/"path": *"//; s/"$//' \
    > "$PATHS_FILE"

  # Sanity check
  if [ ! -s "$PATHS_FILE" ]; then
    return 1
  fi
  echo "Tree loaded: $(wc -l <"$PATHS_FILE") entries"
  return 0
}

# Print the unique systems that have at least one overlay PNG for current $REPO_RES
list_systems_for_resolution() {
  res="$1"
  grep -E "^[A-Z][A-Z0-9]+/${res}/[^/]+/.+\.(png|jpg|jpeg)$" "$PATHS_FILE" \
    | awk -F/ '{print $1}' \
    | sort -u
}

# Print path-line + display-line pairs for every overlay image of [system, res]
# Each emitted line in the items file is the human-readable label.
# We also write a parallel "lookup" file with the matching repo path.
list_overlays_for_system() {
  sys="$1"
  res="$2"
  grep -E "^${sys}/${res}/[^/]+/.+\.(png|jpg|jpeg)$" "$PATHS_FILE" \
    | sort
}

# Convert a repo path like "GB/720p/KrutzOtrem/aspect/Aspect - Vanilla.png"
# into a short friendly label.
# Strategy: drop CORE/RES, keep the bare filename, strip a redundant subdir
# prefix (e.g. "aspect/Aspect - Vanilla" -> "Vanilla"), append "[Author]".
# minui-list has no horizontal scrolling, so short labels matter.
pretty_label_for_path() {
  full="$1"
  rest=$(echo "$full" | sed -E 's#^[^/]+/[^/]+/##')
  author=$(echo "$rest" | awk -F/ '{print $1}')
  remainder=$(echo "$rest" | sed -E 's#^[^/]+/##')
  # remainder = subdir/.../filename (subdir may be empty)
  filename=$(echo "$remainder" | awk -F/ '{print $NF}')
  subdir=$(echo "$remainder" | awk -F/ '{ if (NF>1) {
              s=$1; for (i=2;i<NF;i++) s=s"/"$i; print s
            } else print "" }')
  base=$(echo "$filename" | sed -E 's/\.(png|PNG|jpg|JPG|jpeg|JPEG)$//')

  # If filename starts with the subdir name (case-insensitive) followed by
  # " - " or "_", strip that prefix - it's redundant context.
  if [ -n "$subdir" ]; then
    leaf=$(basename "$subdir")
    short=$(echo "$base" | awk -v p="$leaf" '
      BEGIN { lp=tolower(p) }
      {
        s=$0; ls=tolower(s);
        if (substr(ls,1,length(lp)+3)==lp" - ") print substr(s,length(lp)+4);
        else if (substr(ls,1,length(lp)+1)==lp"_") print substr(s,length(lp)+2);
        else print s
      }')
    echo "${short} [${author}]"
  else
    echo "${base} [${author}]"
  fi
}

# ---------------------------------------------------------------------------
# Install routine
# ---------------------------------------------------------------------------

# Build a unique destination filename so different authors don't collide.
# "GB/720p/KrutzOtrem/aspect/Aspect - Vanilla.png" -> "KrutzOtrem_aspect_Aspect - Vanilla.png"
dest_filename_for_path() {
  full="$1"
  echo "$full" | sed -E 's#^[^/]+/[^/]+/##' | sed 's#/#_#g'
}

# Download a single repo file to a local target. $1=repo path, $2=local file.
download_repo_file() {
  src="$1"; dst="$2"
  url="${RAW_BASE}/$(echo "$src" | sed 's# #%20#g')"
  $CURL -o "$dst.tmp" "$url" || return 1
  mv "$dst.tmp" "$dst"
  return 0
}

# Newer NextUI builds (v6.7+) look for /Overlays/<RES>/<CORE>/*.png so they
# can ship overlays per resolution. Older builds look for /Overlays/<CORE>/.
# We don't know which is in use, and the right answer differs by core (e.g.
# GBC may already work in the legacy path while GBA needs the new one), so
# we just install to both locations. install_one_dir handles a single target.
install_one_dir() {
  dest_dir="$1"
  src_repo_path="$2"
  cfg_src_repo_path="$3"   # may be empty
  unique_stem="$4"
  ext="$5"

  mkdir -p "$dest_dir" || return 1
  dest_png="$dest_dir/${unique_stem}.${ext}"
  dest_cfg="$dest_dir/${unique_stem}.cfg"

  if ! download_repo_file "$src_repo_path" "$dest_png"; then
    return 1
  fi
  echo "INSTALL  $dest_png  ($(stat -c %s "$dest_png" 2>/dev/null || wc -c <"$dest_png") bytes)"

  png_basename=$(basename "$dest_png")

  if [ -n "$cfg_src_repo_path" ]; then
    # The repo provided an explicit cfg - pull it and rewrite the
    # overlayN_overlay = ... line to point at our renamed PNG.
    if download_repo_file "$cfg_src_repo_path" "$dest_cfg"; then
      escaped_basename=$(echo "$png_basename" | sed -e 's/[\/&]/\\&/g')
      sed -E "s|^([[:space:]]*overlay[0-9]+_overlay[[:space:]]*=[[:space:]]*).*$|\1${escaped_basename}|" \
        "$dest_cfg" > "${dest_cfg}.tmp" && mv "${dest_cfg}.tmp" "$dest_cfg"
      echo "INSTALL  $dest_cfg  (from repo)"
      return 0
    fi
  fi

  # No sibling .cfg in the repo (lots of authors only ship the PNG).
  # libretro/minarch needs a .cfg to actually load an overlay, otherwise
  # NextUI will not list it under Options -> Frontend -> Overlay.
  # Synthesise a minimal full-screen overlay config matching the format
  # used elsewhere in the same repo (Perfect_DMG-EX.cfg etc).
  cat >"$dest_cfg" <<EOF
overlays = 1
overlay0_overlay = ${png_basename}
overlay0_full_screen = true
overlay0_descs = 0
EOF
  echo "INSTALL  $dest_cfg  (auto-generated)"
  return 0
}

# Repo organises overlays by the *system* the artwork was made for (GBA, GB,
# FC, ...), but NextUI maps roms to paks by the *tag* in the rom folder name
# (Game Boy Advance (MGBA) -> MGBA.pak -> /Overlays/MGBA/). When the user has
# only an alternate-core pak (e.g. MGBA but no GBA.pak), installing into
# /Overlays/GBA/ does nothing visible in-game.
#
# expand_system_to_tags returns every alias for the given repo system that is
# actually present on this device, by checking for either:
#   - /Emus/<platform>/<TAG>.pak   (the emulator pak is installed), or
#   - /Roms/* (<TAG>)              (a rom folder uses that tag).
# If nothing matches we fall back to the original system name so we still
# write something useful.
expand_system_to_tags() {
  sys="$1"
  case "$sys" in
    GBA)    cands="GBA MGBA GPSP VBA VBANEXT" ;;
    GB)     cands="GB GAMBATTE SAMEBOY MGB" ;;
    GBC)    cands="GBC GAMBATTE SAMEBOY MGB" ;;
    SGB)    cands="SGB" ;;
    FC)     cands="FC NES FCEUMM NESTOPIA QUICKNES" ;;
    FDS)    cands="FDS NES FCEUMM NESTOPIA" ;;
    SFC)    cands="SFC SNES SNES9X SUPA" ;;
    MD)     cands="MD GEN GENESIS PICODRIVE BLASTEM" ;;
    SMS)    cands="SMS PICODRIVE" ;;
    GG)     cands="GG PICODRIVE" ;;
    SEGACD) cands="SEGACD GENESISPLUSGX PICODRIVE" ;;
    PCE)    cands="PCE TGFX BEETLEPCE" ;;
    NGP)    cands="NGP MEDNAFEN" ;;
    NGPC)   cands="NGPC MEDNAFEN" ;;
    A2600)  cands="A2600 STELLA" ;;
    A5200)  cands="A5200 ATARI800" ;;
    A7800)  cands="A7800 PROSYSTEM" ;;
    LYNX)   cands="LYNX HANDY MEDNAFENLYNX" ;;
    VB)     cands="VB MEDNAFENVB BEETLEVB" ;;
    PRBOOM) cands="PRBOOM DOOM" ;;
    PS)     cands="PS PSX PCSXREARMED DUCKSTATION SWANSTATION" ;;
    P8)     cands="P8" ;;
    PKM)    cands="PKM PMINI POKEMINI" ;;
    C64)    cands="C64 VICEX64" ;;
    C128)   cands="C128 VICEX128" ;;
    PLUS4)  cands="PLUS4 VICEXPLUS4" ;;
    VIC)    cands="VIC VIC20 VICEXVIC" ;;
    PET)    cands="PET VICEXPET" ;;
    MSX)    cands="MSX BLUEMSX FMSX" ;;
    AMIGA)  cands="AMIGA PUAE" ;;
    COLECO) cands="COLECO COLECOVISION BLUEMSX" ;;
    CPC)    cands="CPC CRUDE" ;;
    GENERIC) cands="GENERIC" ;;
    *)      cands="$sys" ;;
  esac

  emu_dir="${SDCARD_PATH:-/mnt/SDCARD}/Emus/${PLATFORM:-tg5040}"
  rom_dir="${SDCARD_PATH:-/mnt/SDCARD}/Roms"

  active=""
  for c in $cands; do
    found=0
    if [ -d "$emu_dir/${c}.pak" ]; then
      found=1
    else
      for d in "$rom_dir"/*"(${c})"; do
        [ -d "$d" ] && { found=1; break; }
      done
    fi
    if [ "$found" = "1" ]; then
      active="$active $c"
    fi
  done
  active="${active# }"

  # If we found nothing on the device, still install under the original name -
  # at worst the overlay sits unused, but at best the user installs the
  # matching pak later and it lights up.
  if [ -z "$active" ]; then
    active="$sys"
  fi
  echo "$active"
}

install_overlay() {
  repo_path="$1"  # e.g. GBA/768p/KrutzOtrem/aspect/Aspect - Vanilla.png
  system=$(echo "$repo_path" | awk -F/ '{print $1}')
  res=$(echo    "$repo_path" | awk -F/ '{print $2}')
  base=$(basename "$repo_path")
  ext="${base##*.}"
  stem="${base%.*}"

  unique_stem=$(dest_filename_for_path "$repo_path" | sed -E 's/\.(png|PNG|jpg|JPG|jpeg|JPEG)$//')

  cfg_repo_path=$(dirname "$repo_path")/"${stem}.cfg"
  if ! grep -Fxq "$cfg_repo_path" "$PATHS_FILE"; then
    cfg_repo_path=""
  fi

  tags=$(expand_system_to_tags "$system")
  echo "INSTALL  system=$system tags='$tags' res=$res"

  ok=0
  installed_human=""
  for tag in $tags; do
    if install_one_dir "$OVERLAYS_ROOT/$tag" "$repo_path" "$cfg_repo_path" "$unique_stem" "$ext"; then
      ok=$((ok+1))
      installed_human="${installed_human}/Overlays/$tag/\n"
    fi
    if install_one_dir "$OVERLAYS_ROOT/$res/$tag" "$repo_path" "$cfg_repo_path" "$unique_stem" "$ext"; then
      ok=$((ok+1))
      installed_human="${installed_human}/Overlays/$res/$tag/\n"
    fi
  done

  [ "$ok" -gt 0 ] || return 1
  INSTALL_DEST_HUMAN="$installed_human"
  return 0
}

# ---------------------------------------------------------------------------
# Browse loops
# ---------------------------------------------------------------------------

browse_overlays_for_system() {
  sys="$1"
  res="$REPO_RES"

  paths_for_sys="$WORK_DIR/${sys}_paths.txt"
  labels_for_sys="$WORK_DIR/${sys}_labels.txt"
  list_overlays_for_system "$sys" "$res" > "$paths_for_sys"

  if [ ! -s "$paths_for_sys" ]; then
    show_message "No overlays for $sys at $res" 3
    return
  fi

  : > "$labels_for_sys"
  while IFS= read -r p; do
    pretty_label_for_path "$p" >> "$labels_for_sys"
  done <"$paths_for_sys"

  while :; do
    show_list "$sys ($res)  -  pick overlay" "$labels_for_sys" "PREVIEW" "BACK"
    rc=$?
    classify_helper_rc "$rc"
    case "$HELPER_ACTION" in
      abort) exit "$rc" ;;
      back)  return ;;
    esac

    chosen_label=$(cat "$LIST_OUT_FILE")
    [ -z "$chosen_label" ] && continue

    idx=$(awk -v sel="$chosen_label" '$0==sel{print NR; exit}' "$labels_for_sys")
    [ -z "$idx" ] && continue
    chosen_path=$(sed -n "${idx}p" "$paths_for_sys")

    preview_file="$WORK_DIR/preview_$(echo "$chosen_path" | tr '/ ' '__').png"
    if ! download_repo_file "$chosen_path" "$preview_file"; then
      show_message "Preview failed (network?)" 3
      continue
    fi

    show_preview "$preview_file" "$chosen_label"
    prev_rc=$?
    classify_helper_rc "$prev_rc"
    case "$HELPER_ACTION" in
      abort) exit "$prev_rc" ;;
      ok)
        if install_overlay "$chosen_path"; then
          show_message "Installed to:\n${INSTALL_DEST_HUMAN}" 4
        else
          show_message "Install failed" 3
        fi
        ;;
      back) : ;;
    esac
  done
}

RESOLUTION_SETTING_FILE="$HOME/resolution"

# All resolutions present anywhere in the repo's tree, with a non-empty author folder
available_resolutions() {
  awk -F/ '
    NF >= 4 && $1 ~ /^[A-Z][A-Z0-9]+$/ && $2 ~ /^[0-9]+p$/ {
      tolower_ext = tolower($NF);
      if (match(tolower_ext, /\.(png|jpg|jpeg)$/)) print $2;
    }
  ' "$PATHS_FILE" | sort -u
}

# Pick which resolution to browse: persisted choice -> autodetected -> any available.
choose_resolution() {
  if [ -f "$RESOLUTION_SETTING_FILE" ]; then
    REPO_RES=$(cat "$RESOLUTION_SETTING_FILE")
    return
  fi

  list=$(available_resolutions)
  if [ -z "$list" ]; then
    return  # leave REPO_RES alone; browse_systems will complain
  fi

  if echo "$list" | grep -qx "$REPO_RES"; then
    return  # autodetected works
  fi

  # Autodetected resolution has no overlays. Pick something close.
  fallback=$(echo "$list" | head -n 1)
  echo "Resolution $REPO_RES has no overlays in repo, falling back to $fallback"
  REPO_RES="$fallback"
}

# Show resolution picker (used from the systems menu via X button).
pick_resolution_interactive() {
  res_file="$WORK_DIR/resolutions.txt"
  available_resolutions > "$res_file"
  if [ ! -s "$res_file" ]; then
    show_message "No resolutions available in repo" 3
    return
  fi
  show_list "Choose resolution (current: $REPO_RES)" "$res_file" "USE" "BACK"
  rc=$?
  classify_helper_rc "$rc"
  case "$HELPER_ACTION" in
    abort) exit "$rc" ;;
    back)  return ;;
  esac

  chosen=$(cat "$LIST_OUT_FILE")
  [ -z "$chosen" ] && return
  REPO_RES="$chosen"
  echo "$REPO_RES" > "$RESOLUTION_SETTING_FILE"
}

browse_systems() {
  while :; do
    systems_file="$WORK_DIR/systems_${REPO_RES}.txt"
    list_systems_for_resolution "$REPO_RES" > "$systems_file"

    # Always offer a way to change resolution, even if the current one is empty.
    menu_file="$WORK_DIR/menu.txt"
    if [ -s "$systems_file" ]; then
      cat "$systems_file" > "$menu_file"
    else
      : > "$menu_file"
    fi
    echo "[Change resolution: $REPO_RES]" >> "$menu_file"

    show_list "Pick a system  (res: $REPO_RES)" "$menu_file" "OPEN" "QUIT"
    rc=$?
    classify_helper_rc "$rc"
    case "$HELPER_ACTION" in
      abort) exit "$rc" ;;
      back)  return ;;
    esac

    chosen=$(cat "$LIST_OUT_FILE")
    [ -z "$chosen" ] && return

    case "$chosen" in
      "[Change resolution:"*)
        pick_resolution_interactive
        ;;
      *)
        browse_overlays_for_system "$chosen"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  detect_platform
  ensure_helpers

  if ! fetch_tree; then
    show_message "Could not fetch overlay index. Check Wi-Fi." 5
    return 1
  fi

  choose_resolution
  browse_systems
}

main "$@"
