#!/usr/bin/env python3
"""
Helpers for using a custom HUD's scheme as the base of the font mod.

Why this exists
---------------
A HUD's resource/clientscheme.res usually only contains #base lines, e.g.

    #base "scheme/mm_colors.res"
    #base "scheme/mm_fonts.res"

Copying that file alone into the font mod breaks those includes: they are
resolved relative to the *including file*, so the copies of scheme/*.res must
be placed in the same relative layout.  This script copies the whole #base
closure into the mod's resource/ directory.

It can also add the HUD's own font names (toonhud_montserrat, G_FontSmall, ...)
to the generated override, so text that uses HUD-specific families is replaced
too.  Symbol/icon fonts are skipped.

Usage (normally called by tools/set-font.sh):
    python3 tools/dev/hud_scheme.py copy   <scheme> <hud-resource-dir> <mod-resource-dir>
    python3 tools/dev/hud_scheme.py inject <scheme> <hud-resource-dir> <mod-resource-dir> <font-name>
"""

from __future__ import annotations

import os
import re
import shutil
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from importlib import import_module

bt = import_module("build-templates")

INCLUDE_RE = re.compile(r'^\s*#(?:base|include)\s+"([^"]+)"', re.IGNORECASE)

# Never point these at a text replacement font.
SKIP_NAMES = {
    "marlett", "marlettsmall", "icons", "gameuibuttons",
    "gameuibuttonssmall", "gameuibuttonssmallest",
    "gameuibuttonssteamcontroller", "gameuibuttonssteamcontrollersmall",
    "gameuibuttonssteamcontrollersmallest", "tf2icons", "weaponicons",
}
SKIP_PARTS = ("icon", "symbol", "marlett", "gameuibutton",
              "size:", "crosshair")


def warn(msg: str) -> None:
    print("[!] " + msg, file=sys.stderr)


def includes(path: str) -> list[str]:
    out = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = INCLUDE_RE.match(line)
                if m:
                    out.append(m.group(1).replace("\\", "/"))
    except OSError:
        pass
    return out


def inside(path: str, root: str) -> bool:
    try:
        return os.path.commonpath([os.path.abspath(path), os.path.abspath(root)]) == os.path.abspath(root)
    except ValueError:
        return False


def copy_closure(top: str, hud_res: str, mod_res: str, seen: set[str]) -> None:
    """Copy every file reachable through #base, preserving relative layout."""
    stack = [top]
    while stack:
        src = stack.pop()
        src = os.path.normpath(src)
        if src in seen or not os.path.isfile(src):
            continue
        seen.add(src)

        rel = os.path.relpath(src, hud_res)
        if rel.startswith("..") or os.path.isabs(rel):
            warn("skipping include outside the HUD resource folder: " + src)
            continue

        dst = os.path.join(mod_res, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.abspath(src) != os.path.abspath(dst):
            shutil.copy2(src, dst)

        for inc in includes(src):
            nxt = os.path.normpath(os.path.join(os.path.dirname(src), inc))
            if inside(nxt, hud_res):
                stack.append(nxt)
            else:
                warn("skipping include outside the HUD resource folder: " + inc)


def copy_scheme(scheme: str, hud_res: str, mod_res: str, source_scheme: str | None = None) -> int:
    source_scheme = source_scheme or scheme
    top = os.path.join(hud_res, source_scheme + ".res")
    if not os.path.isfile(top):
        warn("HUD has no %s.res" % source_scheme)
        return 1

    seen: set[str] = set()
    copy_closure(top, hud_res, mod_res, seen)

    # The top-level file is the new base, not resource/clientscheme.res.
    src_base = os.path.join(mod_res, source_scheme + ".res")
    dst_base = os.path.join(mod_res, scheme + "_base.res")
    if os.path.isfile(src_base):
        os.replace(src_base, dst_base)
    else:
        warn("failed to copy %s.res" % source_scheme)
        return 1

    print("copied %d scheme file(s) for %s" % (len(seen), scheme))
    return 0


def load_fonts(path: str) -> dict[str, set[str]]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            tree = bt.parse(bt.tokenize(fh.read()))
    except Exception:
        return {}

    root = tree
    scheme = next((c for c in root.children if c.name.lower() == "scheme" and c.is_block), root)
    fonts = next((c for c in scheme.children if c.name.lower() == "fonts" and c.is_block), None)
    if fonts is None:
        return {}

    out: dict[str, set[str]] = {}
    for font in fonts.children:
        if not font.is_block:
            continue
        blocks = set()
        for block in font.children:
            if not block.is_block:
                continue
            bitmap = next((c for c in block.children if c.name.lower() in ("bitmap", "symbol") and c.value == "1"), None)
            if bitmap is None:
                blocks.add(block.name)
        if blocks:
            out.setdefault(font.name, set()).update(blocks)

    return out


def walk_scheme(path: str, seen: set[str] | None = None) -> list[str]:
    if seen is None:
        seen = set()
    path = os.path.normpath(path)
    if path in seen or not os.path.isfile(path):
        return []
    seen.add(path)
    files = [path]
    for inc in includes(path):
        files.extend(walk_scheme(os.path.join(os.path.dirname(path), inc), seen))
    return files


def sorted_blocks(names: set[str]) -> list[str]:
    def key(v: str):
        try:
            return (0, int(v))
        except ValueError:
            return (1, v)
    return sorted(names, key=key)


def inject(scheme: str, hud_res: str, mod_res: str, font_name: str) -> int:
    scheme_path = os.path.join(mod_res, scheme + ".res")
    if not os.path.isfile(scheme_path):
        warn("generated %s.res not found" % scheme)
        return 1

    with open(scheme_path, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    # Existing font names in the generated template (they already have overrides).
    try:
        tree = bt.parse(bt.tokenize(text))
        root = next((c for c in tree.children if c.name.lower() == "scheme" and c.is_block), tree)
        fonts_node = next((c for c in root.children if c.name.lower() == "fonts" and c.is_block), None)
        existing = {c.name for c in fonts_node.children} if fonts_node is not None else set()
    except Exception:
        existing = set()

    hud_fonts: dict[str, set[str]] = {}
    base = os.path.join(mod_res, scheme + "_base.res")
    for path in walk_scheme(base):
        for name, blocks in load_fonts(path).items():
            hud_fonts.setdefault(name, set()).update(blocks)

    lines = []
    for name in sorted(hud_fonts):
        low = name.lower()
        if name in existing or low in SKIP_NAMES or any(part in low for part in SKIP_PARTS):
            continue
        blocks = sorted_blocks(hud_fonts[name])
        if not blocks:
            continue
        lines.append('\t\t"%s"' % name)
        lines.append("\t\t{")
        for block in blocks:
            lines.append('\t\t\t"%s"\t{ "name" "%s" }' % (block, font_name))
        lines.append("\t\t}")
        lines.append("")
        existing.add(name)

    marker = "// CUSTOMFONT:HUD-FONTS"
    if marker not in text:
        warn("marker %s missing; HUD font names were not added" % marker)
        return 0

    replacement = ("\n".join(lines) + "\n\t\t" + marker) if lines else marker
    text = text.replace(marker, replacement, 1)
    with open(scheme_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

    print("added %d HUD font override(s) for %s" % (sum(1 for l in lines if l.startswith('\t\t"' )), scheme))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 5:
        print(__doc__, file=sys.stderr)
        return 2
    mode, scheme, hud_res, mod_res = argv[1:5]
    if mode == "copy":
        return copy_scheme(scheme, hud_res, mod_res, argv[5] if len(argv) >= 6 else None)
    if mode == "inject" and len(argv) >= 6:
        return inject(scheme, hud_res, mod_res, argv[5])
    print("unknown mode: " + mode, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
