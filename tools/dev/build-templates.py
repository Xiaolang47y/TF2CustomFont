#!/usr/bin/env python3
"""
Rebuild tools/template/{clientscheme,chatscheme}.res from the pristine
scheme files in tools/base/.

The generated files contain placeholders that the set-font scripts replace
at run time:

    __CUSTOM_FONT_SUMMARY__  the per-role font mapping shown in the header
    __CUSTOM_FONT_NAME__     font family name understood by the engine
    __CUSTOM_FONT_FILE__     path of the font inside the mod (resource/...)

Every glyph-set carries a trailing "// CUSTOMFONT:ORIG=<family>" comment.
The scripts use it to assign a different font to each TF2 role (the four
tf2*.ttf families, HUD numbers and every other text family) instead of
forcing one font everywhere.

Only the "name" of every font glyph-set is overridden; sizes, weights,
ranges, colors, borders and every other key is inherited from the base
scheme through the #base directive, so future game updates only require
refreshing tools/base/*.res and re-running this script.

Usage:
    python3 tools/dev/build-templates.py
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE_DIR = os.path.join(ROOT, "tools", "base")
TPL_DIR = os.path.join(ROOT, "tools", "template")

# Fonts that must NOT be replaced: they contain symbols rather than text.
SKIP_FONTS = {
    # Bitmap fonts (vgui .vbf files) - can not be replaced by a TTF.
    "GameUIButtons",
    "GameUIButtonsSmall",
    "GameUIButtonsSmallest",
    "GameUIButtonsSteamController",
    "GameUIButtonsSteamControllerSmall",
    "GameUIButtonsSteamControllerSmallest",
    # Marlett is a symbol font used for scrollbar arrows and window glyphs.
    "Marlett",
    "MarlettSmall",
    # "Icons" uses the Team Fortress symbol font (class icons, etc.).
    "Icons",
}

# Every language token the Source engine may report is listed here so the
# engine applies the full Unicode range to the replacement font.  Without a
# matching language block it falls back to Tahoma/DejaVu for non-Latin text.
LANGUAGES = [
    "english", "german", "french", "italian", "korean", "spanish",
    "schinese", "tchinese", "russian", "thai", "japanese", "portuguese",
    "brazilian", "latam", "polish", "danish", "dutch", "finnish",
    "norwegian", "swedish", "czech", "hungarian", "romanian", "turkish",
    "bulgarian", "greek", "ukrainian", "vietnamese",
]

CUSTOM_FONT_ID = "1000"  # arbitrary unique key; HUDs may already use "100" (crosshairs)
MARKER = "TF2_CUSTOM_FONT_OVERRIDE"


class Node:
    __slots__ = ("name", "value", "children")

    def __init__(self, name=None, value=None):
        self.name = name
        self.value = value
        self.children = [] if value is None else None

    @property
    def is_block(self):
        return self.children is not None


def tokenize(text: str):
    """Very small KeyValues tokenizer (quoted strings, braces, conditionals)."""
    tokens = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n":
            i += 1
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if c == "[":
            j = text.find("]", i)
            i = n if j < 0 else j + 1
            tokens.append("[condition]")
            continue
        if c == "{":
            tokens.append("{")
            i += 1
            continue
        if c == "}":
            tokens.append("}")
            i += 1
            continue
        if c == '"':
            i += 1
            buf = []
            while i < n:
                ch = text[i]
                if ch == "\\" and i + 1 < n:
                    buf.append(text[i + 1])
                    i += 2
                    continue
                if ch == '"':
                    i += 1
                    break
                buf.append(ch)
                i += 1
            tokens.append("".join(buf))
            continue
        j = i
        while j < n and text[j] not in " \t\r\n{}[]":
            j += 1
        tokens.append(text[i:j])
        i = j
    return tokens


def parse(tokens):
    root = Node()
    stack = [root]
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "}":
            if len(stack) > 1:
                stack.pop()
            i += 1
            continue
        key = tok
        i += 1
        while i < len(tokens) and tokens[i] == "[condition]":
            i += 1
        if i < len(tokens) and tokens[i] == "{":
            node = Node(key)
            stack[-1].children.append(node)
            stack.append(node)
            i += 1
        else:
            value = tokens[i] if i < len(tokens) and tokens[i] != "}" else ""
            if i < len(tokens) and tokens[i] != "}":
                i += 1
            while i < len(tokens) and tokens[i] == "[condition]":
                i += 1
            stack[-1].children.append(Node(key, value))
    return root


def child(node, name):
    for c in node.children:
        if c.name.lower() == name.lower():
            return c
    return None


def fmt_block_name(name: str) -> str:
    return '"%s"' % name


def build_scheme(scheme_name: str, base_file: str, title: str) -> str:
    with open(os.path.join(BASE_DIR, base_file), "r", encoding="utf-8", errors="replace") as fh:
        tree = parse(tokenize(fh.read()))

    scheme = child(tree, "Scheme")
    if scheme is None:
        raise SystemExit("no Scheme block in %s" % base_file)
    fonts = child(scheme, "Fonts")
    if fonts is None:
        raise SystemExit("no Fonts block in %s" % base_file)

    out = []
    out.append("// " + "=" * 74)
    out.append("//  %s" % title)
    out.append("//")
    out.append("//  Template generated by tools/dev/build-templates.py.")
    out.append("//  Normal use: run tools/set-font.sh (Linux) or tools\\set-font.cmd")
    out.append("//  (Windows) to regenerate this file for another font - no manual")
    out.append("//  editing needed. Marker: %s" % MARKER)
    out.append("//")
    out.append("//  Font mapping (see --list-fonts in the scripts):")
    out.append("// __CUSTOM_FONT_SUMMARY__")
    out.append("//")
    out.append("//  Every glyph-set carries // CUSTOMFONT:ORIG=<original family>.")
    out.append("//  Everything except the font names is inherited from")
    out.append('//  "%s" (vanilla scheme or a custom HUD scheme).' % (scheme_name + "_base.res"))
    out.append("// " + "=" * 74)
    out.append("")
    out.append('#base "%s_base.res"' % scheme_name)
    out.append("")
    out.append("Scheme")
    out.append("{")
    out.append("\t// CUSTOMFONT:CUSTOM-FILE-BEGIN")
    out.append("\t// Registered only when a role uses a custom font file.")
    out.append("\tCustomFontFiles")
    out.append("\t{")
    out.append('\t\t"%s"' % CUSTOM_FONT_ID)
    out.append("\t\t{")
    out.append('\t\t\t"font"\t"__CUSTOM_FONT_FILE__"')
    out.append('\t\t\t"name"\t"__CUSTOM_FONT_NAME__"')
    out.append("")
    out.append("\t\t\t// CUSTOMFONT:RANGE-BEGIN")
    out.append("\t\t\t// The range blocks make the engine use the replacement font for")
    out.append("\t\t\t// the whole Unicode range instead of falling back to a system font.")
    out.append("\t\t\t// Remove them (or use --no-range / -NoRange) if the font only has")
    out.append("\t\t\t// Latin glyphs and you want CJK text to fall back to a system font.")
    for lang in LANGUAGES:
        out.append('\t\t\t"%s"\t{ "range" "0x0000 0xFFFF" }' % lang)
    out.append("\t\t\t// CUSTOMFONT:RANGE-END")
    out.append("\t\t}")
    out.append("\t}")
    out.append("\t// CUSTOMFONT:CUSTOM-FILE-END")
    out.append("")
    out.append("\tFonts")
    out.append("\t{")
    out.append("\t\t// Each glyph-set is replaced according to its original family")
    out.append("\t\t// (CUSTOMFONT:ORIG).  Only the name is written, so tall/weight/")
    out.append("\t\t// antialias/... still come from the base.")
    count = 0
    for font in fonts.children:
        if not font.is_block:
            continue
        if font.name in SKIP_FONTS:
            continue
        blocks = [b for b in font.children if b.is_block]
        if not blocks:
            continue
        # Skip pure bitmap fonts even if the name was not in the list.
        if all(any(k.name == "bitmap" and k.value == "1" for k in b.children if not k.is_block) for b in blocks):
            continue
        out.append("")
        out.append('\t\t"%s"' % font.name)
        out.append("\t\t{")
        for block in blocks:
            original = next(
                (c.value for c in block.children if not c.is_block and c.name.lower() == "name"),
                "",
            )
            out.append(
                '\t\t\t"%s"\t{ "name" "__CUSTOM_FONT_NAME__" }\t// CUSTOMFONT:ORIG=%s'
                % (block.name, original)
            )
        out.append("\t\t}")
        count += 1
    out.append("\t\t// CUSTOMFONT:HUD-FONTS")
    out.append("\t}")
    out.append("}")
    out.append("")
    sys.stderr.write("%s: %d font families overridden\n" % (os.path.basename(base_file), count))
    return "\n".join(out)


def main():
    os.makedirs(TPL_DIR, exist_ok=True)
    jobs = [
        ("clientscheme", "clientscheme.res", "TF2 Custom Font - clientscheme override"),
        ("chatscheme", "chatscheme.res", "TF2 Custom Font - chatscheme override"),
    ]
    for scheme_name, base_file, title in jobs:
        text = build_scheme(scheme_name, base_file, title)
        path = os.path.join(TPL_DIR, scheme_name + ".res")
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        sys.stderr.write("wrote %s (%d bytes)\n" % (path, len(text.encode("utf-8"))))


if __name__ == "__main__":
    main()
