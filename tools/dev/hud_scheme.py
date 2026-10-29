#!/usr/bin/env python3
"""
Helpers for using a custom HUD's scheme as the base of the font mod, and for
mapping one font per TF2 role.

Why this exists
---------------
A HUD's resource/clientscheme.res usually only contains #base lines, e.g.

    #base "scheme/mm_colors.res"
    #base "scheme/mm_fonts.res"

Copying that file alone into the font mod breaks those includes: they are
resolved relative to the *including file*, so the copies of scheme/*.res must
be placed in the same relative layout.  This script copies the whole #base
closure into the mod's resource/ directory.

It can also add the HUD's own font families (toonhud_montserrat, G_FontSmall,
...) to the generated override.  Symbol/icon fonts are skipped.

Roles
-----
The four fonts TF2 ships (tf2.ttf, tf2build.ttf, tf2secondary.ttf,
tf2professor.ttf) and every other text font form these roles:

    tf2, build, secondary, professor   original tf2*.ttf families
    numbers                            "Team Fortress" (HUD numbers)
    body                               Verdana, Arial, Tahoma, ...
    hud                                families only a custom HUD defines

A role can keep its original family or point at another family.  The
generated template already knows the *vanilla* origin of every glyph-set;
with a custom HUD a family may be remapped (e.g. Default -> G_FontSmall), so
remap mode rewrites the names using the actual HUD base.

Usage (normally called by tools/set-font.sh):
    python3 tools/dev/hud_scheme.py copy   <scheme> <hud-resource-dir> <mod-resource-dir> [source-scheme]
    python3 tools/dev/hud_scheme.py remap  <scheme> <mod-resource-dir> <role-map>
    python3 tools/dev/hud_scheme.py inject <scheme> <hud-resource-dir> <mod-resource-dir> <role-map>

<role-map> is "role=family|role=family|..." where "keep" means "do not
replace this role".
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

KEEP = "keep"
ROLE_ORDER = ("tf2", "build", "secondary", "professor", "body", "numbers", "hud")

# Original family -> role.  These are the four fonts shipped in tf/*.ttf.
STOCK_ROLES = {
    "TF2": "tf2",
    "TF2 Build": "build",
    "TF2 Secondary": "secondary",
    "TF2 Professor": "professor",
}
# "Team Fortress" is the bitmap-like family used for HUD numbers/ammo.
NUMBER_FAMILIES = {"Team Fortress"}
# Regular text fonts (system families and the HUD's own body fonts).
BODY_FAMILIES = {
    "tfd", "Tahoma", "Arial Black", "Courier New", "ocra", "Verdana",
    "Trebuchet MS", "Arial", "OCR A Extended",
}

FONTS_LINE_RE = re.compile(r'^\s*"?Fonts"?\s*$', re.IGNORECASE)
FAMILY_LINE_RE = re.compile(r'^\s*"([^"]+)"\s*$')
BLOCK_LINE_RE = re.compile(r'^\s*"(?P<key>[^"]+)"\s*\{\s*"name"\s*"[^"]*"\s*\}\s*(?://.*)?$')
ORIG_COMMENT_RE = re.compile(r'//\s*CUSTOMFONT:ORIG=(.*)$')


def warn(msg: str) -> None:
    print("[!] " + msg, file=sys.stderr)


def role_for(origin: str) -> str:
    """Classify an original font family name into a replacement role."""
    if origin in STOCK_ROLES:
        return STOCK_ROLES[origin]
    if origin in NUMBER_FAMILIES:
        return "numbers"
    if origin in BODY_FAMILIES:
        return "body"
    # Everything else is family that only a custom HUD defines.
    return "hud"


def parse_role_map(spec: str) -> dict[str, str]:
    """Parse "tf2=TF2 Build|build=keep|..." into {role: target family}."""
    roles: dict[str, str] = {}
    for pair in spec.split("|"):
        pair = pair.strip()
        if not pair or "=" not in pair:
            continue
        key, value = pair.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if key not in ROLE_ORDER:
            warn("ignoring unknown role in map: " + key)
            continue
        if value.lower() in ("", KEEP, "original", "none"):
            value = KEEP
        roles[key] = value
    return roles


def target_for(origin: str, roles: dict[str, str]) -> str:
    """Return the replacement family for origin, or origin to keep it."""
    target = roles.get(role_for(origin), KEEP)
    if target.lower() == KEEP:
        return origin
    return target


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


def load_fonts(path: str) -> dict[str, dict[str, str]]:
    """Return {family: {glyph_set: original_family_name}} for text fonts."""
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

    out: dict[str, dict[str, str]] = {}
    for font in fonts.children:
        if not font.is_block:
            continue
        blocks: dict[str, str] = {}
        for block in font.children:
            if not block.is_block:
                continue
            bitmap = next((c for c in block.children if c.name.lower() in ("bitmap", "symbol") and c.value == "1"), None)
            if bitmap is not None:
                continue
            original = next(
                (c.value for c in block.children
                 if not c.is_block and c.name.lower() == "name"),
                "",
            )
            blocks[block.name] = original
        if not blocks:
            continue
        out.setdefault(font.name, {}).update(blocks)

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


def base_origins(base_path: str) -> dict[tuple[str, str], str]:
    origins: dict[tuple[str, str], str] = {}
    for path in walk_scheme(base_path):
        for family, blocks in load_fonts(path).items():
            for block, original in blocks.items():
                origins[(family, block)] = original
    return origins


def rewrite_family(name: str) -> str:
    return name.replace("\\", "\\\\").replace('"', '\\"')


def remap_scheme(scheme: str, mod_res: str, role_map: str) -> int:
    """Point every glyph-set at the font of its role, using the actual base."""
    scheme_path = os.path.join(mod_res, scheme + ".res")
    base_path = os.path.join(mod_res, scheme + "_base.res")
    if not os.path.isfile(scheme_path):
        warn("generated %s.res not found" % scheme)
        return 1

    roles = parse_role_map(role_map)
    origins = base_origins(base_path)

    with open(scheme_path, "r", encoding="utf-8", errors="replace", newline="") as fh:
        lines = fh.read().splitlines(keepends=True)

    out: list[str] = []
    in_fonts = False
    pending_open = False
    depth = 0
    family = None
    changed = 0
    for line in lines:
        body = line.rstrip("\r\n")
        newline = line[len(body):]
        if not in_fonts:
            out.append(line)
            if FONTS_LINE_RE.match(body):
                in_fonts = True
                pending_open = True
            continue
        if pending_open:
            out.append(line)
            if body.strip() == "{":
                depth = 1
                pending_open = False
            continue
        block = BLOCK_LINE_RE.match(body)
        if block is not None and family is not None:
            key = block.group("key")
            origin = origins.get((family, key))
            if origin is None:
                comment = ORIG_COMMENT_RE.search(body)
                origin = comment.group(1).strip() if comment else ""
            if origin:
                target = target_for(origin, roles)
                indent = body[:len(body) - len(body.lstrip())]
                out.append(
                    f'{indent}"{key}"\t{{ "name" "{rewrite_family(target)}" }}\t// CUSTOMFONT:ORIG={origin}{newline}'
                )
                changed += 1
            else:
                out.append(line)
            depth += body.count("{") - body.count("}")
            continue
        family_match = FAMILY_LINE_RE.match(body)
        if family_match is not None and depth == 1:
            family = family_match.group(1)
        out.append(line)
        depth += body.count("{") - body.count("}")
        if depth <= 0:
            in_fonts = False
            pending_open = False
            family = None

    with open(scheme_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("".join(out))

    print("remapped %d glyph-set(s) for %s" % (changed, scheme))
    return 0


def inject(scheme: str, hud_res: str, mod_res: str, role_map: str) -> int:
    """Add HUD-only font families (and HUD-only glyph-sets) to the override."""
    scheme_path = os.path.join(mod_res, scheme + ".res")
    if not os.path.isfile(scheme_path):
        warn("generated %s.res not found" % scheme)
        return 1

    roles = parse_role_map(role_map)

    with open(scheme_path, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    try:
        tree = bt.parse(bt.tokenize(text))
        root = next((c for c in tree.children if c.name.lower() == "scheme" and c.is_block), tree)
        fonts_node = next((c for c in root.children if c.name.lower() == "fonts" and c.is_block), None)
        existing = {c.name for c in fonts_node.children} if fonts_node is not None else set()
    except Exception:
        existing = set()

    hud_fonts: dict[str, dict[str, str]] = {}
    base = os.path.join(mod_res, scheme + "_base.res")
    for path in walk_scheme(base):
        for name, blocks in load_fonts(path).items():
            hud_fonts.setdefault(name, {}).update(blocks)

    lines: list[str] = []
    for name in sorted(hud_fonts):
        low = name.lower()
        if name in existing or low in SKIP_NAMES or any(part in low for part in SKIP_PARTS):
            continue
        entries = []
        for block in sorted(hud_fonts[name], key=_block_key):
            origin = hud_fonts[name][block]
            target = target_for(origin, roles)
            if target != origin:
                entries.append((block, target, origin))
        if not entries:
            continue
        lines.append('\t\t"%s"' % name)
        lines.append("\t\t{")
        for block, target, origin in entries:
            lines.append(
                f'\t\t\t"{block}"\t{{ "name" "{rewrite_family(target)}" }}\t// CUSTOMFONT:ORIG={origin}'
            )
        lines.append("\t\t}")
        lines.append("")
        existing.add(name)

    marker = "// CUSTOMFONT:HUD-FONTS"
    if marker not in text:
        warn("marker %s missing; HUD font names were not added" % marker)
        return 0

    # Replace the marker including the indentation of its line, so the first
    # injected family starts at the same level as the existing ones.
    replacement = ("\n".join(lines) + "\n\t\t" + marker) if lines else marker
    text = re.sub(r'[ \t]*' + re.escape(marker), lambda _m: replacement, text, count=1)
    with open(scheme_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

    print("added %d HUD font override(s) for %s"
          % (sum(1 for l in lines if l.startswith('\t\t"')), scheme))
    return 0


def _block_key(value: str):
    try:
        return (0, int(value))
    except ValueError:
        return (1, value)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    mode = argv[1]
    if mode == "copy" and len(argv) >= 5:
        return copy_scheme(argv[2], argv[3], argv[4], argv[5] if len(argv) >= 6 else None)
    if mode == "remap" and len(argv) >= 5:
        return remap_scheme(argv[2], argv[3], argv[4])
    if mode == "inject" and len(argv) >= 6:
        return inject(argv[2], argv[3], argv[4], argv[5])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
