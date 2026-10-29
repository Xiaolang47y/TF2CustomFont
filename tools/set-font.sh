#!/usr/bin/env bash
#
# set-font.sh - replace the font used by the TF2 "!000_customfont" mod.
#
# Reads the family name from a TTF/OTF file, copies the file into the mod and
# regenerates resource/clientscheme.res + resource/chatscheme.res from the
# templates in tools/template/.
#
# TF2 uses four original fonts (tf2.ttf, tf2build.ttf, tf2secondary.ttf,
# tf2professor.ttf) for different kinds of text.  They are exposed as the
# roles tf2, build, secondary and professor.  Three more roles cover the rest
# of the text: body (Verdana/Arial/...), numbers ("Team Fortress", HUD
# numbers/ammo) and hud (families only a custom HUD defines).  Every role can
# use a different font file, or keep its original family.
#
# Usage:
#   ./tools/set-font.sh /path/to/font.ttf [options]
#   ./tools/set-font.sh --font tf2=1.ttf --font build=1.ttf \
#       --font secondary=2.ttf --font professor=2.ttf
#
# Options:
#   --font ROLE=FILE   Use FILE for ROLE.  Can be repeated.  ROLE is one of
#                      tf2, build, secondary, professor, body, numbers, hud;
#                      aliases tf2build/tf2secondary/tf2professor are accepted.
#   --keep ROLE[,ROLE] Keep the original family for the given role(s).
#   --name NAME        Use NAME instead of the family name stored in the file.
#                      --name ROLE=NAME overrides only that role.
#   --list-fonts       Show the selectable roles and their original families.
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
#   ./tools/set-font.sh --font tf2=~/Fonts/1.ttf --font build=~/Fonts/1.ttf \
#       --font secondary=~/Fonts/2.ttf --font professor=~/Fonts/2.ttf
#   ./tools/set-font.sh ~/Downloads/Inter.ttf --keep numbers
#   ./tools/set-font.sh ~/Downloads/Inter.ttf --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
#   ./tools/set-font.sh --restore --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SCRIPT_DIR/template"
BASE_DIR="$SCRIPT_DIR/base"
MARKER="TF2_CUSTOM_FONT_OVERRIDE"

ROLE_NAMES=(tf2 build secondary professor body numbers hud)
ROLE_ORIGINS=("TF2" "TF2 Build" "TF2 Secondary" "TF2 Professor" \
              "Verdana, Arial, Tahoma, ..." "Team Fortress" "HUD-only families")

FONT_FILE=""
GLOBAL_NAME=""
HUD_PATH=""
USE_RANGE=1
HUD_USED=0
RESTORE=0
LIST_FONTS=0
TARGET_DIR="$REPO_DIR/tf/custom/!000_customfont"

# Per-role state (indexed by the position in ROLE_NAMES).
ROLE_FILE=("" "" "" "" "" "" "")
ROLE_KEEP=(0 0 0 0 0 0 0)
ROLE_NAME=("" "" "" "" "" "" "")
ROLE_TARGET=("" "" "" "" "" "" "")

# Unique custom font registrations: source path + family name.
REG_PATH=()
REG_NAME=()
REG_DEST=()
REG_FIRST_ROLE=()

say()  { printf '%s\n' "$*"; }
ok()   { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
set-font.sh - replace the fonts used by the TF2 "!000_customfont" mod.

Usage:
  ./tools/set-font.sh /path/to/font.ttf [options]
  ./tools/set-font.sh --font tf2=1.ttf --font build=1.ttf \
      --font secondary=2.ttf --font professor=2.ttf

Roles (each can use a different font):
  tf2 = TF2              build     = TF2 Build
  secondary = TF2 Secondary        professor = TF2 Professor
  body = Verdana/Arial/...         numbers   = Team Fortress (HUD numbers)
  hud = families only a custom HUD defines

Options:
  --font ROLE=FILE   Use FILE for ROLE. Repeatable. The roles tf2build,
                     tf2secondary and tf2professor are aliases for build,
                     secondary and professor.
  --keep ROLE[,ROLE] Keep the original family for the given role(s).
  --name NAME        Use NAME instead of the family name stored in the file.
                     --name ROLE=NAME overrides only that role.
  --list-fonts       Show the selectable roles and their original families.
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
  # One font for everything
  ./tools/set-font.sh ~/Downloads/Inter.ttf

  # tf2build + tf2secondary -> 1.ttf, tf2 + tf2professor -> 2.ttf
  ./tools/set-font.sh --font build=~/Fonts/1.ttf --font secondary=~/Fonts/1.ttf \
      --font tf2=~/Fonts/2.ttf --font professor=~/Fonts/2.ttf

  # Everything except the HUD damage numbers
  ./tools/set-font.sh ~/Downloads/Inter.ttf --keep numbers

  # With a custom HUD
  ./tools/set-font.sh --font tf2=1.ttf --font build=1.ttf \
      --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
EOF
    exit "${1:-0}"
}

role_index() {
    case "$1" in
        tf2|tf2.ttf)              printf '%s\n' 0 ;;
        build|tf2build|tf2build.ttf) printf '%s\n' 1 ;;
        secondary|tf2secondary|tf2secondary.ttf) printf '%s\n' 2 ;;
        professor|tf2professor|tf2professor.ttf) printf '%s\n' 3 ;;
        body)                     printf '%s\n' 4 ;;
        numbers)                  printf '%s\n' 5 ;;
        hud)                      printf '%s\n' 6 ;;
        *)                        return 1 ;;
    esac
}

show_roles() {
    say "Selectable roles (use --font ROLE=FILE or --keep ROLE):"
    local i alias
    for i in "${!ROLE_NAMES[@]}"; do
        alias=""
        case "${ROLE_NAMES[$i]}" in
            build)      alias="  (alias: tf2build)" ;;
            secondary)  alias="  (alias: tf2secondary)" ;;
            professor)  alias="  (alias: tf2professor)" ;;
        esac
        printf '  %-11s %-30s%s\n' "${ROLE_NAMES[$i]}" "${ROLE_ORIGINS[$i]}" "$alias"
    done
    say ""
    say "Unassigned roles keep their original family.  The first positional"
    say "font file (or --font all=FILE) sets the default for every role."
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
        --font)
            [ $# -ge 2 ] || die "--font needs ROLE=FILE"
            arg="$2"
            [ "${arg#*=}" != "$arg" ] || die "--font expects ROLE=FILE, got '$arg'"
            role="${arg%%=*}"
            file="${arg#*=}"
            role="${role,,}"
            if [ "$role" = "all" ]; then
                FONT_FILE="$file"
            else
                idx="$(role_index "$role")" || die "unknown role '$role' (use --list-fonts)"
                ROLE_FILE[$idx]="$file"
                ROLE_KEEP[$idx]=0
            fi
            shift 2 ;;
        --keep)
            [ $# -ge 2 ] || die "--keep needs a role list"
            for role in ${2//,/ }; do
                role="${role,,}"
                idx="$(role_index "$role")" || die "unknown role '$role' (use --list-fonts)"
                ROLE_FILE[$idx]=""
                ROLE_KEEP[$idx]=1
            done
            shift 2 ;;
        --name)
            [ $# -ge 2 ] || die "--name needs a value"
            if [ "${2#*=}" != "$2" ]; then
                role="${2%%=*}"
                role="${role,,}"
                if idx="$(role_index "$role")"; then
                    ROLE_NAME[$idx]="${2#*=}"
                    shift 2
                    continue
                fi
            fi
            GLOBAL_NAME="$2"
            shift 2 ;;
        --list-fonts) LIST_FONTS=1; shift ;;
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

if [ "$LIST_FONTS" -eq 1 ]; then
    show_roles
    exit 0
fi

if [ "$RESTORE" -eq 1 ]; then
    resolve_hud_res
    restore_hud_scheme clientscheme
    restore_hud_scheme chatscheme
    say ""
    say "HUD schemes restored. Remove the font mod folder if you no longer need it."
    exit 0
fi

if [ -z "$FONT_FILE" ]; then
    any_font=0
    for f in "${ROLE_FILE[@]}"; do
        if [ -n "$f" ]; then any_font=1; break; fi
    done
    [ "$any_font" -eq 1 ] || usage 1
fi

# ---------------------------------------------------------------------------
# validate role font files
# ---------------------------------------------------------------------------
for idx in "${!ROLE_FILE[@]}"; do
    f="${ROLE_FILE[$idx]}"
    [ -z "$f" ] && continue
    [ -f "$f" ] || die "font file not found for ${ROLE_NAMES[$idx]}: $f"
    case "${f##*.}" in
        ttf|otf|ttc|otc) ;;
        *) warn "unusual file extension '${f##*.}' for ${ROLE_NAMES[$idx]}; the game expects a TrueType/OpenType font" ;;
    esac
done
if [ -n "$FONT_FILE" ]; then
    [ -f "$FONT_FILE" ] || die "font file not found: $FONT_FILE"
    case "${FONT_FILE##*.}" in
        ttf|otf|ttc|otc) ;;
        *) warn "unusual file extension '${FONT_FILE##*.}'; the game expects a TrueType/OpenType font" ;;
    esac
fi

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

PYTHON=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
fi

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

        [ -n "$PYTHON" ] || die "python3 is required for --hud"
        "$PYTHON" "$SCRIPT_DIR/dev/hud_scheme.py" copy "$scheme" "$HUD_RES_DIR" "$RES_DIR" "$source" \
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
# assign roles and build the unique font registrations
# ---------------------------------------------------------------------------
find_registration() {
    local path="$1" name="$2" i
    for i in "${!REG_PATH[@]}"; do
        # The engine indexes custom fonts by family name, so one family can
        # only be registered once even if several files contain it.
        if [ "${REG_NAME[$i]}" = "$name" ]; then
            if [ "${REG_PATH[$i]}" != "$path" ]; then
                warn "family '$name' appears in both ${REG_PATH[$i]} and $path; using the first file."
            fi
            REG_FOUND="$i"
            return 0
        fi
    done
    REG_FOUND=-1
    return 1
}

for idx in "${!ROLE_NAMES[@]}"; do
    family=""
    src=""
    if [ "${ROLE_KEEP[$idx]}" -eq 1 ]; then
        family="keep"
        [ -n "${ROLE_NAME[$idx]}" ] && warn "--name for ${ROLE_NAMES[$idx]} ignored because the role is kept"
    else
        src="${ROLE_FILE[$idx]}"
        [ -n "$src" ] || src="$FONT_FILE"
        if [ -z "$src" ]; then
            family="keep"
        else
            if [ -n "${ROLE_NAME[$idx]}" ]; then
                family="${ROLE_NAME[$idx]}"
            elif [ -n "$GLOBAL_NAME" ]; then
                family="$GLOBAL_NAME"
            else
                if ! family="$(detect_font_name "$src")"; then
                    family="$(basename "${src%.*}")"
                    warn "could not read the font family name of $src; falling back to '$family'."
                    warn "If the game shows the default font, re-run with --name ROLE=\"<exact family name>\"."
                fi
            fi
            [ -n "$family" ] || die "empty font name for ${ROLE_NAMES[$idx]}"
            if printf '%s' "$family" | LC_ALL=C grep -q '[^ -~]'; then
                warn "the family name '$family' contains non-ASCII characters; it works on Linux but may not match on Windows."
            fi

            if find_registration "$src" "$family"; then
                :
            else
                REG_PATH+=("$src")
                REG_NAME+=("$family")
                REG_DEST+=("")
                REG_FIRST_ROLE+=("${ROLE_NAMES[$idx]}")
                REG_FOUND=$(( ${#REG_PATH[@]} - 1 ))
            fi
        fi
    fi
    ROLE_TARGET[$idx]="$family"
done

# Destination names: keep the historical customfont.<ext> for a single font,
# otherwise one file per role so every registration stays reachable.
for i in "${!REG_PATH[@]}"; do
    ext="$(printf '%s' "${REG_PATH[$i]##*.}" | tr 'A-Z' 'a-z')"
    case "$ext" in
        ttf|otf|ttc|otc) ;;
        *)
            warn "unusual file extension for ${REG_PATH[$i]}; installing as .ttf"
            ext="ttf"
            ;;
    esac
    if [ "${#REG_PATH[@]}" -eq 1 ]; then
        REG_DEST[$i]="resource/customfont.$ext"
    else
        REG_DEST[$i]="resource/customfont_${REG_FIRST_ROLE[$i]}.$ext"
    fi
done

# ---------------------------------------------------------------------------
# role map ("role=family|role=keep") and the header summary
# ---------------------------------------------------------------------------
ROLE_SPEC=""
SUMMARY=""
ROLE_LINES=()
for idx in "${!ROLE_NAMES[@]}"; do
    role="${ROLE_NAMES[$idx]}"
    target="${ROLE_TARGET[$idx]}"
    if [ "${target,,}" = "keep" ]; then
        target="keep"
        line="${target} (original: ${ROLE_ORIGINS[$idx]})"
    else
        line="${target} (custom)"
    fi
    [ -n "$ROLE_SPEC" ] && ROLE_SPEC="$ROLE_SPEC|"
    ROLE_SPEC="${ROLE_SPEC}${role}=${target}"
    # The first line follows "// " in the template, the rest need "//  ".
    printf -v padded '%-11s' "$role"
    ROLE_LINES+=("${padded} -> ${line}")
    if [ -z "$SUMMARY" ]; then
        SUMMARY=" ${padded} -> ${line}"
    else
        SUMMARY="${SUMMARY}
//  ${padded} -> ${line}"
    fi
done
say "Role mapping:"
for line in "${ROLE_LINES[@]}"; do say "  ${line}"; done

# ---------------------------------------------------------------------------
# copy the fonts (read them first so target files can be the input, too)
# ---------------------------------------------------------------------------
WORKDIR="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$WORKDIR"' EXIT
for i in "${!REG_PATH[@]}"; do
    cp -f "${REG_PATH[$i]}" "$WORKDIR/font$i" || die "failed to read ${REG_PATH[$i]}"
done

rm -f "$RES_DIR"/customfont.ttf "$RES_DIR"/customfont.otf \
      "$RES_DIR"/customfont.ttc "$RES_DIR"/customfont.otc \
      "$RES_DIR"/customfont_*.ttf "$RES_DIR"/customfont_*.otf \
      "$RES_DIR"/customfont_*.ttc "$RES_DIR"/customfont_*.otc 2>/dev/null
for i in "${!REG_PATH[@]}"; do
    cp -f "$WORKDIR/font$i" "$RES_DIR/${REG_DEST[$i]#resource/}" || die "failed to copy font ${REG_DEST[$i]}"
    chmod 644 "$RES_DIR/${REG_DEST[$i]#resource/}" 2>/dev/null || true
    ok "installed $RES_DIR/${REG_DEST[$i]#resource/} (${REG_NAME[$i]})"
done

escape_res() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# CustomFontFiles block (replaces the CUSTOM-FILE-BEGIN/END section).
make_custom_block() {
    local i
    printf '\t// CUSTOMFONT:CUSTOM-FILE-BEGIN\n'
    printf '\t// Registered only when a role uses a custom font file.\n'
    printf '\tCustomFontFiles\n'
    printf '\t{\n'
    for i in "${!REG_PATH[@]}"; do
        printf '\t\t"%s"\n' "$((1000 + i))"
        printf '\t\t{\n'
        printf '\t\t\t"font"\t"%s"\n' "$(escape_res "${REG_DEST[$i]}")"
        printf '\t\t\t"name"\t"%s"\n' "$(escape_res "${REG_NAME[$i]}")"
        printf '\n'
        if [ "$USE_RANGE" -eq 1 ]; then
            printf '\t\t\t// CUSTOMFONT:RANGE-BEGIN\n'
            printf '\t\t\t// The range blocks make the engine use the replacement font for\n'
            printf '\t\t\t// the whole Unicode range instead of falling back to a system font.\n'
            printf '\t\t\t// Remove them (or use --no-range / -NoRange) if the font only has\n'
            printf '\t\t\t// Latin glyphs and you want CJK text to fall back to a system font.\n'
            for lang in english german french italian korean spanish schinese tchinese \
                        russian thai japanese portuguese brazilian latam polish danish \
                        dutch finnish norwegian swedish czech hungarian romanian turkish \
                        bulgarian greek ukrainian vietnamese; do
                printf '\t\t\t"%s"\t{ "range" "0x0000 0xFFFF" }\n' "$lang"
            done
            printf '\t\t\t// CUSTOMFONT:RANGE-END\n'
        fi
        printf '\t\t}\n'
        [ "$i" -lt $(( ${#REG_PATH[@]} - 1 )) ] && printf '\n'
    done
    printf '\t}\n'
    printf '\t// CUSTOMFONT:CUSTOM-FILE-END\n'
}

# ---------------------------------------------------------------------------
# regenerate the scheme overrides
# ---------------------------------------------------------------------------
make_scheme() {
    local scheme="$1"
    local tpl="$TEMPLATE_DIR/$scheme.res"
    local out="$RES_DIR/$scheme.res"
    local blockfile="$WORKDIR/block.res"
    local primary_family="${REG_NAME[0]:-keep}"
    local primary_file="${REG_DEST[0]:-resource/customfont.ttf}"
    local content
    [ -f "$tpl" ] || die "template missing: $tpl"

    make_custom_block > "$blockfile" || die "failed to build the CustomFontFiles block"

    # Replace the CustomFontFiles block first (line based), then use plain
    # parameter expansion for the placeholders: unlike awk's gsub, bash does
    # not treat '&' or '\' in the replacement as special.
    sentinel_block="$WORKDIR/removed-block.txt"
    awk -v blockfile="$blockfile" '
        /CUSTOMFONT:CUSTOM-FILE-BEGIN/ {
            while ((getline l < blockfile) > 0) print l
            skip = 1
            next
        }
        /CUSTOMFONT:CUSTOM-FILE-END/ { skip = 0; next }
        skip { next }
        { print }
    ' "$tpl" > "$WORKDIR/$scheme.step1.res" || die "failed to prepare $out"

    content="$(cat "$WORKDIR/$scheme.step1.res")" || die "failed to read $tpl"
    content="${content//__CUSTOM_FONT_SUMMARY__/$SUMMARY}"
    content="${content//__CUSTOM_FONT_NAME__/$primary_family}"
    content="${content//__CUSTOM_FONT_FILE__/$primary_file}"

    # Without Python only one family can be applied; remap is required when a
    # role keeps its original family or uses a second font.  Check before
    # writing so a failed run does not leave a half-patched scheme behind.
    if [ -z "$PYTHON" ]; then
        families="$(printf '%s\n' "$SUMMARY" | grep -c 'custom)' || true)"
        if [ "$families" -ne "${#ROLE_NAMES[@]}" ] || [ "${#REG_PATH[@]}" -ne 1 ]; then
            die "python3 is required to assign different fonts to different roles or to keep a role"
        fi
    fi

    printf '%s\n' "$content" > "$out" || die "failed to write $out"

    if [ -n "$HUD_RES_DIR" ]; then
        [ -n "$PYTHON" ] || die "python3 is required for --hud"
        "$PYTHON" "$SCRIPT_DIR/dev/hud_scheme.py" remap "$scheme" "$RES_DIR" "$ROLE_SPEC" \
            || die "failed to remap $scheme.res for the selected roles"
    elif [ -n "$PYTHON" ]; then
        "$PYTHON" "$SCRIPT_DIR/dev/hud_scheme.py" remap "$scheme" "$RES_DIR" "$ROLE_SPEC" \
            || die "failed to remap $scheme.res for the selected roles"
    fi

    if [ "$HUD_USED" -eq 1 ] && [ -n "$HUD_RES_DIR" ]; then
        "$PYTHON" "$SCRIPT_DIR/dev/hud_scheme.py" inject "$scheme" "$HUD_RES_DIR" "$RES_DIR" "$ROLE_SPEC" \
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
say "  - Use --list-fonts to see the assignable roles."
say "  - If text is still the old font, check that the family name matches exactly"
say "    and that no HUD/mod with a clientscheme.res sorts before !000_customfont."
