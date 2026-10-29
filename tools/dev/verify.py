#!/usr/bin/env python3
"""
Sanity check for the generated templates and the role-aware remapping.

It simulates the engine's #base merge (KeyValues::MergeBaseKeys) and asserts
that

  * a single font still replaces every text glyph-set,
  * the role map (tools/dev/hud_scheme.py remap) points each glyph-set at the
    family of its original role, while kept roles stay unchanged,
  * icon/symbol fonts are never touched,
  * CustomFontFiles, Colors, Borders and BaseSettings survive the merge,
  * the deployed files in tf/custom/!000_customfont/resource parse.

Usage:
    python3 tools/dev/verify.py
"""

from __future__ import annotations

import copy
import os
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importlib import import_module

bt = import_module("build-templates")
hs = import_module("hud_scheme")

ROOT = bt.ROOT
NAME = "Font One"
FILE = "resource/customfont_build.ttf"
ROLE_MAP = ("tf2=Font Two|build=Font One|secondary=Font One|"
            "professor=Font Two|body=Font One|numbers=keep|hud=keep")


def load(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return bt.parse(bt.tokenize(fh.read()))


def merge(base, cur):
    """Mirror KeyValues::RecursiveMergeKeyValues: both sides win over base."""
    if not base.is_block or not cur.is_block:
        return
    for bc in base.children:
        match = None
        for cc in cur.children:
            if cc.name == bc.name:
                match = cc
                break
        if match is not None:
            merge(bc, match)
        else:
            cur.children.append(copy.deepcopy(bc))


def find(node, name):
    for c in node.children:
        if c.name.lower() == name.lower():
            return c
    return None


def template_text(scheme):
    path = os.path.join(ROOT, "tools", "template", scheme + ".res")
    text = open(path, "r", encoding="utf-8").read()
    return (text.replace("__CUSTOM_FONT_SUMMARY__", " test mapping")
                .replace("__CUSTOM_FONT_NAME__", NAME)
                .replace("__CUSTOM_FONT_FILE__", FILE))


def check_single_font(scheme, base, skips):
    """The template alone (no remap) must replace every text glyph-set."""
    failures = []
    tpl = bt.parse(bt.tokenize(template_text(scheme)))
    merged = copy.deepcopy(tpl)
    merge(base, merged)

    base_fonts = find(find(base, "Scheme"), "Fonts")
    merged_fonts = find(find(merged, "Scheme"), "Fonts")
    if merged_fonts is None:
        return ["%s: Fonts section lost" % scheme], 0

    merged_by_name = {}
    for f in merged_fonts.children:
        merged_by_name.setdefault(f.name, []).append(f)

    overridden = 0
    counted = set()
    for font in base_fonts.children:
        if not font.is_block:
            continue
        candidates = merged_by_name.get(font.name, [])
        if not candidates:
            failures.append("%s: font %s disappeared" % (scheme, font.name))
            continue
        for block in [b for b in font.children if b.is_block]:
            key = (font.name, block.name)
            if key in counted:
                continue
            counted.add(key)
            mblocks = [b for b in candidates[0].children if b.is_block and b.name == block.name]
            if not mblocks:
                failures.append("%s: %s/%s disappeared" % (scheme, font.name, block.name))
                continue
            name_node = find(mblocks[0], "name")
            got = name_node.value if name_node else None
            if font.name in skips:
                base_name = find(block, "name")
                if got != (base_name.value if base_name else None):
                    failures.append("%s: skipped font %s was modified" % (scheme, font.name))
            elif got != NAME:
                failures.append("%s: %s/%s name = %r" % (scheme, font.name, block.name, got))
            else:
                overridden += 1

    # colors / borders / custom font files must survive
    for section in ("Colors", "Borders", "BaseSettings", "CustomFontFiles"):
        b = find(find(base, "Scheme"), section)
        m = find(find(merged, "Scheme"), section)
        if b is not None and (m is None or len(m.children) < len(b.children)):
            failures.append("%s: section %s was damaged" % (scheme, section))

    cf = find(find(merged, "Scheme"), "CustomFontFiles")
    entry = next((c for c in cf.children if c.name == bt.CUSTOM_FONT_ID), None)
    if entry is None or find(entry, "name").value != NAME or find(entry, "font").value != FILE:
        failures.append("%s: CustomFontFiles entry missing/broken" % scheme)

    return failures, overridden


def check_roles(scheme, base, skips):
    """Remap the generated file with a role map and verify every glyph-set."""
    failures = []
    roles = hs.parse_role_map(ROLE_MAP)

    with tempfile.TemporaryDirectory(prefix="customfont-verify-") as tmp:
        base_path = os.path.join(tmp, scheme + "_base.res")
        shutil.copyfile(os.path.join(ROOT, "tools", "base", scheme + ".res"), base_path)

        scheme_path = os.path.join(tmp, scheme + ".res")
        with open(scheme_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(template_text(scheme))

        if hs.remap_scheme(scheme, tmp, ROLE_MAP) != 0:
            return ["%s: remap failed" % scheme], 0

        text = open(scheme_path, "r", encoding="utf-8").read()
        if "__CUSTOM_FONT" in text:
            failures.append("%s: remapped file still contains placeholders" % scheme)

        tpl = bt.parse(bt.tokenize(text))
        merged = copy.deepcopy(tpl)
        merge(copy.deepcopy(base), merged)

    merged_fonts = find(find(merged, "Scheme"), "Fonts")
    if merged_fonts is None:
        return failures + ["%s: Fonts section lost after remap" % scheme], 0

    origins = hs.base_origins(os.path.join(ROOT, "tools", "base", scheme + ".res"))
    remapped = 0
    counted = set()
    for font in merged_fonts.children:
        if not font.is_block:
            continue
        for block in [b for b in font.children if b.is_block]:
            key = (font.name, block.name)
            if key in counted:
                continue
            counted.add(key)
            origin = origins.get(key)
            name_node = find(block, "name")
            got = name_node.value if name_node else None
            if origin is None:
                continue
            if font.name in skips:
                expected = origin
            else:
                expected = hs.target_for(origin, roles)
            if got != expected:
                failures.append("%s: %s/%s = %r, expected %r (origin %r)"
                                % (scheme, font.name, block.name, got, expected, origin))
            elif got != origin:
                remapped += 1

    return failures, remapped


def main():
    failures = []

    jobs = [
        ("clientscheme", bt.SKIP_FONTS),
        ("chatscheme", {"Marlett", "MarlettSmall"}),
    ]
    for scheme, skips in jobs:
        base = load(os.path.join(ROOT, "tools", "base", scheme + ".res"))
        single_failures, overridden = check_single_font(scheme, base, skips)
        failures.extend(single_failures)
        print("%-14s %3d glyph-sets overridden (single font)" % (scheme, overridden))

        role_failures, remapped = check_roles(scheme, base, skips)
        failures.extend(role_failures)
        print("%-14s %3d glyph-sets remapped (role map)" % (scheme, remapped))

    # The shipped (already expanded) files must also be parseable.
    deployed = os.path.join(ROOT, "tf", "custom", "!000_customfont", "resource")
    for scheme in ("clientscheme", "chatscheme"):
        path = os.path.join(deployed, scheme + ".res")
        if not os.path.exists(path):
            continue
        text = open(path, "r", encoding="utf-8", errors="replace").read()
        if "__CUSTOM_FONT" in text:
            failures.append("%s.res still contains placeholders" % scheme)
        try:
            bt.parse(bt.tokenize(text))
        except Exception as exc:
            failures.append("%s.res does not parse: %s" % (scheme, exc))
        print("%-14s deployed file parsed" % scheme)

    if failures:
        print("\nFAILED")
        for f in failures:
            print("  -", f)
        return 1
    print("\nOK: #base merge and role mapping produce the expected result")
    return 0


if __name__ == "__main__":
    sys.exit(main())
