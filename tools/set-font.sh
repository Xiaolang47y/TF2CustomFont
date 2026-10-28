#!/usr/bin/env bash
#
# set-font.sh - replace the font used by the TF2 "!000_customfont" mod.
#
# Reads the family name from a TTF/OTF file, copies the file into the mod and
# regenerates resource/clientscheme.res + resource/chatscheme.res from the
# templates in tools/template/.
#
# Usage:
#   ./tools/set-font.sh /path/to/font.ttf [options]
#
# Options:
#   --name NAME        Use NAME instead of the family name stored in the file.
#   --hud PATH         Copy an installed HUD's scheme (including every #base
#                      file), rename the HUD's own scheme aside, and keep its
#                      colours/layout. Requires python3.
#   --no-range         Do not force the font on the full Unicode range. Use it
#                      for Latin-only fonts if CJK text should fall back to a
#                      system font instead of showing empty boxes.
#   --target PATH      Mod folder to patch (default: <repo>/tf/custom/!000_customfont).
#   --restore          Undo --hud and restore the HUD's own scheme files.
#   -h, --help         Show this help.
#
# Examples:
#   ./tools/set-font.sh ~/Downloads/Inter.ttf
#   ./tools/set-font.sh ~/Downloads/Comic.ttf --name "Comic Sans MS"
#   ./tools/set-font.sh ~/Downloads/Inter.ttf --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
#   ./tools/set-font.sh --restore --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SCRIPT_DIR/template"
BASE_DIR="$SCRIPT_DIR/base"
MARKER="TF2_CUSTOM_FONT_OVERRIDE"

FONT_FILE=""
FONT_NAME=""
HUD_PATH=""
USE_RANGE=1
HUD_USED=0
RESTORE=0
TARGET_DIR="$REPO_DIR/tf/custom/!000_customfont"

say()  { printf '%s\n' "$*"; }
ok()   { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
set-font.sh - replace the font used by the TF2 "!000_customfont" mod.

Usage:
  ./tools/set-font.sh /path/to/font.ttf [options]

Options:
  --name NAME        Use NAME instead of the family name stored in the file.
  --hud PATH         Copy an installed HUD's scheme (including every #base
                     file) and move the HUD's own scheme aside, so the mod is
                     not shadowed. Keeps the HUD's colours/layout.
  --no-range         Do not force the font on the full Unicode range (Latin-only
                     fonts: CJK text then falls back to a system font).
  --target PATH      Mod folder to patch
                     (default: <repo>/tf/custom/!000_customfont).
  --restore          Undo --hud and restore the HUD's own scheme files.
  -h, --help         Show this help.

Examples:
  ./tools/set-font.sh ~/Downloads/Inter.ttf
  ./tools/set-font.sh ~/Downloads/Comic.ttf --name "Comic Sans MS"
  ./tools/set-font.sh ~/Downloads/Inter.ttf \
      --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
EOF
    exit "${1:-0}"
}

resolve_hud_res() {
    [ -n "$HUD_PATH" ] || die "--restore/--hud requires a HUD path"
    [ -d "$HUD_PATH" ] || die "HUD path not found: $HUD_PATH"
    if [ -f "$HUD_PATH/resource/clientscheme.res" ] || [ -f "$HUD_PATH/resource/chatscheme.res" ] \
       || [ -f "$HUD_PATH/resource/clientscheme_customfont_original.res" ] \
       || [ -f "$HUD_PATH/resource/chatscheme_customfont_original.res" ]; then
        HUD_RES_DIR="$HUD_PATH/resource"
    elif [ -f "$HUD_PATH/clientscheme.res" ] || [ -f "$HUD_PATH/chatscheme.res" ] \
         || [ -f "$HUD_PATH/clientscheme_customfont_original.res" ] \
         || [ -f "$HUD_PATH/chatscheme_customfont_original.res" ]; then
        HUD_RES_DIR="$HUD_PATH"
    else
        die "no clientscheme.res/chatscheme.res found in $HUD_PATH (expected <hud>/resource/)"
    fi
}

restore_hud_scheme() {
    local scheme="$1"
    local original="$HUD_RES_DIR/${scheme}_customfont_original.res"
    local target="$HUD_RES_DIR/${scheme}.res"
    if [ ! -f "$original" ]; then
        warn "no backup found for $scheme.res in $HUD_RES_DIR"
        return 0
    fi
    if [ -f "$target" ] && grep -q "$MARKER" "$target" 2>/dev/null; then
        rm -f "$target"
    fi
    if [ ! -f "$target" ]; then
        mv "$original" "$target"
        ok "restored $target"
    else
        warn "not restoring $target: it exists and is not the font-mod wrapper"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --name)   [ $# -ge 2 ] || die "--name needs a value"; FONT_NAME="$2"; shift 2 ;;
        --hud)    [ $# -ge 2 ] || die "--hud needs a value"; HUD_PATH="$2"; shift 2 ;;
        --no-range) USE_RANGE=0; shift ;;
        --target) [ $# -ge 2 ] || die "--target needs a value"; TARGET_DIR="$2"; shift 2 ;;
        --restore) RESTORE=1; shift ;;
        -h|--help) usage 0 ;;
        --) shift; break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)
            if [ -z "$FONT_FILE" ]; then FONT_FILE="$1"; else die "unexpected argument: $1"; fi
            shift ;;
    esac
done
if [ $# -gt 0 ] && [ -z "$FONT_FILE" ]; then FONT_FILE="$1"; fi

if [ "$RESTORE" -eq 1 ]; then
    resolve_hud_res
    restore_hud_scheme clientscheme
    restore_hud_scheme chatscheme
    say ""
    say "HUD schemes restored. Remove the font mod folder if you no longer need it."
    exit 0
fi

[ -n "$FONT_FILE" ] || usage 1
[ -f "$FONT_FILE" ] || die "font file not found: $FONT_FILE"

case "${FONT_FILE##*.}" in
    ttf|otf|ttc|otc) ;;
    *) warn "unusual file extension '${FONT_FILE##*.}'; the game expects a TrueType/OpenType font" ;;
esac

# ---------------------------------------------------------------------------
# font family name
# ---------------------------------------------------------------------------
detect_font_name() {
    local file="$1" name=""

    if command -v fc-scan >/dev/null 2>&1; then
        name="$(fc-scan --format '%{family[0]}
' "$file" 2>/dev/null | head -n 1)"
        if [ -n "$name" ]; then printf '%s\n' "$name"; return 0; fi
    fi

    if command -v fc-query >/dev/null 2>&1; then
        name="$(fc-query --format '%{family[0]}
' "$file" 2>/dev/null | head -n 1)"
        if [ -n "$name" ]; then printf '%s\n' "$name"; return 0; fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        name="$(python3 - "$file" <<'PY' 2>/dev/null
import sys
try:
    from fontTools.ttLib import TTFont
except Exception:
    sys.exit(1)
try:
    font = TTFont(sys.argv[1], fontNumber=0, lazy=True)
except Exception:
    sys.exit(1)
records = font["name"].names
for want_english in (True, False):
    for rec in records:
        if rec.nameID != 1:
            continue
        if want_english and rec.platformID == 3 and rec.langID == 0x409:
            print(rec.toUnicode())
            sys.exit(0)
        if not want_english:
            print(rec.toUnicode())
            sys.exit(0)
sys.exit(1)
PY
)"
        if [ -n "$name" ]; then printf '%s\n' "$name"; return 0; fi
    fi

    return 1
}

if [ -z "$FONT_NAME" ]; then
    if ! FONT_NAME="$(detect_font_name "$FONT_FILE")"; then
        FONT_NAME="$(basename "${FONT_FILE%.*}")"
        warn "could not read the font family name; falling back to '$FONT_NAME'."
        warn "If the game shows the default font, re-run with --name \"<exact family name>\"."
    fi
fi
[ -n "$FONT_NAME" ] || die "empty font name"

if printf '%s' "$FONT_NAME" | LC_ALL=C grep -q '[^ -~]'; then
    warn "the family name contains non-ASCII characters; it works on Linux but may not match on Windows."
fi
say "Font family : $FONT_NAME"
say "Font file   : $FONT_FILE"

# ---------------------------------------------------------------------------
# target mod folder
# ---------------------------------------------------------------------------
[ -d "$TARGET_DIR" ] || die "mod folder not found: $TARGET_DIR
Point --target at .../Team Fortress 2/tf/custom/!000_customfont"
RES_DIR="$TARGET_DIR/resource"
[ -d "$RES_DIR" ] || die "no resource folder in $TARGET_DIR"

# ---------------------------------------------------------------------------
# optional HUD schemes
# ---------------------------------------------------------------------------
HUD_RES_DIR=""
if [ -n "$HUD_PATH" ]; then
    resolve_hud_res
fi

install_base() {
    local scheme="$1"
    local original="$HUD_RES_DIR/${scheme}_customfont_original.res"
    local target="$HUD_RES_DIR/${scheme}.res"
    local source="$scheme"

    if [ -n "$HUD_RES_DIR" ]; then
        if [ -f "$target" ] && ! grep -q "$MARKER" "$target" 2>/dev/null; then
            source="$scheme"
            if [ -f "$original" ]; then
                warn "$original is an older backup; using the current HUD $scheme.res as the base."
            fi
        elif [ -f "$original" ]; then
            # Already patched once: the original was moved aside.
            source="${scheme}_customfont_original"
            ok "using the existing HUD backup $source.res"
        else
            warn "HUD has no usable $scheme.res; using the vanilla base."
            cp -f "$BASE_DIR/$scheme.res" "$RES_DIR/${scheme}_base.res" \
                || die "failed to install ${scheme}_base.res"
            return 0
        fi

        command -v python3 >/dev/null 2>&1 || die "python3 is required for --hud"
        python3 "$SCRIPT_DIR/dev/hud_scheme.py" copy "$scheme" "$HUD_RES_DIR" "$RES_DIR" "$source" \
            || die "failed to copy the HUD's $source.res tree"

        if [ "$source" = "$scheme" ] && [ -f "$target" ]; then
            if [ -f "$original" ]; then
                warn "keeping the existing backup $original; not overwriting it."
            else
                mv "$target" "$original" || die "failed to move $target aside"
                ok "moved HUD $scheme.res aside (backup: $(basename "$original"))"
            fi
        fi

        HUD_USED=1
        ok "base: $scheme.res from HUD ($HUD_RES_DIR)"
        return 0
    fi

    cp -f "$BASE_DIR/$scheme.res" "$RES_DIR/${scheme}_base.res" \
        || die "failed to install ${scheme}_base.res"
}

install_base clientscheme
install_base chatscheme

# The engine mounts tf/custom/* in ascending order and searches the first
# match, so an alphabetically earlier folder wins.  Warn when a HUD's scheme
# will shadow this mod.
CUSTOM_DIR="$(dirname "$TARGET_DIR")"
if [ -d "$CUSTOM_DIR" ]; then
    winning=""
    while IFS= read -r d; do
        if [ -f "$CUSTOM_DIR/$d/resource/clientscheme.res" ]; then
            winning="$d"
            break
        fi
    done < <(find "$CUSTOM_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
    if [ -n "$winning" ] && [ "$winning" != "$(basename "$TARGET_DIR")" ]; then
        warn "'$winning' is searched before '$(basename "$TARGET_DIR")' and has a clientscheme.res."
        warn "The mod will not work. Use --hud '$CUSTOM_DIR/$winning' or rename its scheme."
    fi
fi


# ---------------------------------------------------------------------------
# copy the font
# ---------------------------------------------------------------------------
EXT="$(printf '%s' "${FONT_FILE##*.}" | tr 'A-Z' 'a-z')"
case "$EXT" in
    ttf|otf|ttc|otc) ;;
    *)
        warn "unusual file extension '$EXT'; installing as customfont.ttf"
        EXT="ttf"
        ;;
esac
FONT_REL="resource/customfont.$EXT"

# keep the bytes in memory so a target file can also be used as input
TMP_FONT="$(mktemp)" || die "mktemp failed"
trap 'rm -f "$TMP_FONT"' EXIT
cat "$FONT_FILE" > "$TMP_FONT" || die "failed to read font file"
rm -f "$RES_DIR"/customfont.ttf "$RES_DIR"/customfont.otf \
      "$RES_DIR"/customfont.ttc "$RES_DIR"/customfont.otc 2>/dev/null
cp -f "$TMP_FONT" "$RES_DIR/customfont.$EXT" || die "failed to copy font"
chmod 644 "$RES_DIR/customfont.$EXT" 2>/dev/null || true
ok "installed $RES_DIR/customfont.$EXT"

# ---------------------------------------------------------------------------
# regenerate the scheme overrides
# ---------------------------------------------------------------------------
make_scheme() {
    local scheme="$1"
    local tpl="$TEMPLATE_DIR/$scheme.res"
    local out="$RES_DIR/$scheme.res"
    local content
    [ -f "$tpl" ] || die "template missing: $tpl"
    content="$(cat "$tpl")" || die "failed to read $tpl"
    content="${content//__CUSTOM_FONT_NAME__/$FONT_NAME}"
    content="${content//__CUSTOM_FONT_FILE__/$FONT_REL}"
    if [ "$USE_RANGE" -eq 0 ]; then
        content="$(printf '%s\n' "$content" | awk '
            /CUSTOMFONT:RANGE-BEGIN/ { skip = 1; next }
            /CUSTOMFONT:RANGE-END/   { skip = 0; next }
            !skip { print }
        ')"
    fi
    printf '%s\n' "$content" > "$out" || die "failed to write $out"
    if [ "$HUD_USED" -eq 1 ] && [ -n "$HUD_RES_DIR" ]; then
        python3 "$SCRIPT_DIR/dev/hud_scheme.py" inject "$scheme" "$HUD_RES_DIR" "$RES_DIR" "$FONT_NAME" \
            || warn "could not add the HUD's extra font names; its own text fonts may stay unchanged."
    fi
    ok "wrote $out"
}

make_scheme clientscheme
make_scheme chatscheme

say ""
say "Done. Files patched in:"
say "  $TARGET_DIR"
say ""
say "Install / update: copy 'tf/custom/!000_customfont' into"
say "  <Steam>/steamapps/common/Team Fortress 2/tf/custom/"
say "then restart TF2, or type 'hud_reloadscheme' in the developer console."
say ""
say "Notes:"
say "  - Windows users can run tools\\set-font.cmd instead."
say "  - If text is still the old font, check that the family name matches exactly"
say "    and that no HUD/mod with a clientscheme.res sorts before !000_customfont."
