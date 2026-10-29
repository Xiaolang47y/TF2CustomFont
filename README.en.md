# TF2 Custom Font Mod (`!000_customfont`)

A client-side Team Fortress 2 mod that replaces the in-game fonts with any TrueType/OpenType
font you like. You can use one font everywhere, or assign different fonts to the four original
TF2 font groups (`TF2`, `TF2 Build`, `TF2 Secondary`, `TF2 Professor`) and to body text, HUD
numbers and custom-HUD fonts. Works on Windows and Linux. Two helper scripts read the **font
family name** from the font file and patch the mod for you.

> Client-side UI only (HUD, chat, menus, kill feed). Same category as a custom HUD. No gameplay
> changes, no injection.

The full documentation is in Chinese in [README.md](README.md); this file is a compact English
guide covering the same workflow.

---

## What it does

- Overrides every text font in `resource/clientscheme.res` (155 families / 229 glyph sets):
  HUD, scoreboard, target ID, kill feed, contracts, store, replay, main menu, …
- **Per-role fonts:** `TF2`, `TF2 Build`, `TF2 Secondary`, `TF2 Professor`, body text
  (Verdana/Arial/Tahoma/…), HUD numbers (`Team Fortress`) and custom-HUD-only families can each
  use a different font file, or keep the original family.
- Overrides `resource/chatscheme.res` (chat + chat input).
- Uses `#base` and overrides **only** the `"name"` of each font, so colours, borders, sizes,
  weights and shadows are inherited from the vanilla scheme or from your custom HUD.
- Keeps symbol/bitmap fonts untouched (`Marlett`, `MarlettSmall`, `Icons`, `GameUIButtons*`), so
  scrollbar arrows, class icons and controller button glyphs keep working.
- Ships DejaVu Sans as a working default; swap it for anything else.

---

## Install

Copy the folder `tf/custom/!000_customfont` into:

| OS | Path |
| --- | --- |
| Windows | `...\Steam\steamapps\common\Team Fortress 2\tf\custom\!000_customfont` |
| Linux | `~/.steam/steam/steamapps/common/Team Fortress 2/tf/custom/!000_customfont` |
| Linux (alt) | `~/.local/share/Steam/steamapps/common/Team Fortress 2/tf/custom/!000_customfont` |
| Flatpak | `~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Team Fortress 2/tf/custom/!000_customfont` |
| Steam Deck | `/home/deck/.local/share/Steam/steamapps/common/Team Fortress 2/tf/custom/!000_customfont` |

Then start TF2, or type `hud_reloadscheme` in the developer console.

### Load order (important)

`tf/gameinfo.txt` mounts `tf/custom/*` in **ascending name order**, and Source uses the **first
matching file**. An earlier folder therefore wins. `!` (0x21) sorts before letters and `-`, so
`!000_customfont` beats `-middle-mann-v26`, `mastercomfig-*`, `workshop`, etc.

The old `zzz_customfont` name was wrong: it sorted **after** `-middle-mann-v26`, so the HUD's
`clientscheme.res` was found first and the font mod was never loaded. Underscores are fine; the
problem was the sort order.

If you have another folder that sorts before `!000_customfont` (for example `!0000_...`) and also
contains `resource/clientscheme.res`, rename that folder or move this mod earlier.

### Custom HUDs

A HUD ships its own `resource/clientscheme.res`. If the HUD is found first, the font mod does
nothing; if the font mod is found first, the HUD's colours/layout are replaced by the vanilla
scheme. Use `--hud` / `-Hud` to solve both problems:

```bash
./tools/set-font.sh ~/Downloads/Inter.ttf --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
```

```bat
tools\set-font.cmd "C:\Fonts\Inter.ttf" -Hud "C:\...\tf\custom\flawhud"
```

The script:

1. resolves `<HUD>/resource/clientscheme.res` (and `chatscheme.res`),
2. copies the **whole `#base` dependency tree** into the mod, preserving relative paths,
   and renames the top-level copy to `*_base.res`,
3. renames the HUD's own scheme to `*_customfont_original.res` so it no longer shadows the mod,
4. regenerates the font overrides and adds HUD-only text families (`G_FontSmall`, `G_FontMedium`,
   …) automatically; icon and crosshair fonts are skipped.

HUD colours, borders, layout and HUD text fonts are preserved.

On Windows the recursive copy is native PowerShell; automatic injection of HUD-only text families
and per-role mapping require Python 3. Without Python, a single font for all roles is still applied
to the vanilla families, but HUD-only names such as `G_FontSmall` keep their original font.

Undo it with:

```bash
./tools/set-font.sh --restore --hud "<...>/tf/custom/flawhud"
```

```bat
tools\set-font.cmd -Restore -Hud "C:\...\tf\custom\flawhud"
```

`--hud` modifies the installed HUD folder (renames, does not delete). If you update the HUD, run
`--restore` first, update, then run `--hud` again. Sharing the mod folder does not patch another
machine's HUD; run `--hud` there.

---

## Change the font

### Windows

```bat
tools\set-font.cmd "C:\path\to\font.ttf"
tools\set-font.cmd "C:\path\to\font.ttf" -Hud "C:\...\tf\custom\myhud"
tools\set-font.cmd "C:\path\to\font.ttf" -Name "Comic Sans MS"
tools\set-font.cmd "C:\path\to\font.ttf" -NoRange
tools\set-font.cmd "C:\path\to\font.ttf" -Target "C:\...\tf\custom\!000_customfont"
tools\set-font.cmd "C:\path\to\font.ttf" -Keep numbers
tools\set-font.cmd -Font "build=1.ttf,secondary=1.ttf,tf2=2.ttf,professor=2.ttf"
tools\set-font.cmd -ListFonts
```

### Linux

```bash
chmod +x tools/set-font.sh          # zip extraction may drop the executable bit
./tools/set-font.sh ~/Downloads/Inter.ttf
./tools/set-font.sh ~/Downloads/Inter.ttf --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
./tools/set-font.sh ~/Downloads/Inter.ttf --name "Comic Sans MS"
./tools/set-font.sh ~/Downloads/Inter.ttf --no-range
./tools/set-font.sh ~/Downloads/Inter.ttf --target ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/!000_customfont
./tools/set-font.sh ~/Downloads/Inter.ttf --keep numbers
./tools/set-font.sh --font build=1.ttf --font secondary=1.ttf --font tf2=2.ttf --font professor=2.ttf
./tools/set-font.sh --list-fonts
```

### Per-role fonts

TF2 draws different text with four original fonts. The scripts expose seven roles:

| Role | Original family | Mainly affects |
| --- | --- | --- |
| `tf2` | `TF2` | main-menu titles, large HUD text, some scoreboard/replay headers |
| `build` | `TF2 Build` | bold HUD, item names, store, matchmaking UI |
| `secondary` | `TF2 Secondary` | small HUD text, scoreboard, buttons and hints |
| `professor` | `TF2 Professor` | chalkboard/contract text |
| `body` | `Verdana`, `Arial`, `Tahoma`, `Trebuchet MS`, `OCR A Extended`, … | default text, chat, hints, debug overlay |
| `numbers` | `Team Fortress` | HUD numbers, ammo and damage numbers |
| `hud` | families defined only by a custom HUD (e.g. `G_FontSmall`) | used with `--hud` |

`tf2build`, `tf2secondary` and `tf2professor` are aliases for `build`, `secondary` and
`professor`.

Example — `TF2 Build` + `TF2 Secondary` use `1.ttf`, `TF2` + `TF2 Professor` use `2.ttf`:

```bat
tools\set-font.cmd -Font "build=C:\Fonts\1.ttf,secondary=C:\Fonts\1.ttf,tf2=C:\Fonts\2.ttf,professor=C:\Fonts\2.ttf"
```

```bash
./tools/set-font.sh --font build=~/Fonts/1.ttf --font secondary=~/Fonts/1.ttf \
    --font tf2=~/Fonts/2.ttf --font professor=~/Fonts/2.ttf
```

Rules:

- An explicit `--font` / `-Font` role wins; other roles use the positional/default font;
  roles with neither keep the original family. On Windows, put several `-Font` entries in
  one quoted argument (PowerShell does not allow the same parameter twice).
- `--keep` / `-Keep` keeps the original family for the listed roles (e.g. `--keep numbers`).
- Each unique family is registered once in `CustomFontFiles` (keys `1000`, `1001`, …), so different
  roles can really use different files. The same file used by several roles is copied only once.
- Different font files with the same family name trigger a warning; the first file wins.
- Per-role assignment or keeping a role requires Python 3 (used by `tools/dev/hud_scheme.py`).
  A single font for all roles still works without Python.

What the script does:

1. Reads the family name (`GDI+ PrivateFontCollection` with the en-US name on Windows,
   `fc-scan`/`fc-query`/`fontTools` on Linux).
2. Copies the font(s) to `resource/customfont.<ext>`, or `resource/customfont_<role>.<ext>` when
   several fonts are used.
3. Copies the vanilla scheme, or the HUD's full `#base` tree with `--hud`.
4. Regenerates `clientscheme.res` / `chatscheme.res` from `tools/template/*.res`, rewriting every
   glyph-set according to its original family (`// CUSTOMFONT:ORIG=...`) and the role map.
5. Prints the role mapping, the result and a load-order warning.

The script patches the package by default; add `--target` to patch an already installed copy.
After changing the font, restart TF2 (custom font files are registered at startup;
`hud_reloadscheme` alone may not reload the file).

---

## Manual method (no script)

1. Find the family name:

   ```powershell
   Add-Type -AssemblyName System.Drawing
   $p = New-Object System.Drawing.Text.PrivateFontCollection
   $p.AddFontFile("C:\path\font.ttf")
   $p.Families[0].GetName(0x0409)   # en-US name
   ```

   ```bash
   fc-scan --format '%{family[0]}\n' /path/font.ttf
   ```

2. Copy the font to `tf/custom/!000_customfont/resource/customfont.ttf` (keep the real extension).
   For several fonts, use one file per role (e.g. `customfont_tf2.ttf`) and register each family
   in `CustomFontFiles` with its own key (`"1000"`, `"1001"`, …).
3. In **both** `resource/clientscheme.res` and `resource/chatscheme.res`, replace every occurrence
   of the current family name (see the `CustomFontFiles` block) with the new one. For per-role
   fonts, edit each glyph-set individually using its `// CUSTOMFONT:ORIG=<family>` comment;
   glyph-sets left on their original family keep that name.
4. If the file is `.otf`, change `"font" "resource/customfont.ttf"` to the real path.
5. Save as UTF-8 **without BOM** (or Windows ANSI) and restart TF2.

Manual edits to the generated files are lost the next time the script runs. For permanent tweaks,
edit `tools/template/*.res` instead.

For a HUD, also copy every `#base` file and rename the HUD's `clientscheme.res` /
`chatscheme.res` to `*_customfont_original.res`; the script is much safer.

---

## CJK / Cyrillic / other scripts

- The default DejaVu Sans has Latin, Greek and Cyrillic glyphs but **no CJK**. For Chinese,
  Japanese or Korean UI use a font that contains those glyphs (Noto Sans CJK SC, Source Han Sans,
  Sarasa Gothic, …). Do not redistribute proprietary fonts.
- By default `CustomFontFiles` sets the language range to `0x0000 0xFFFF`, forcing your font for
  the whole Unicode range.
- **Windows Tahoma fallback:** `CFontManager::SetFontGlyphSet` uses Tahoma beyond `0x00FF` for any
  font that is not in the engine's Asian-font whitelist **unless** a matching `CustomFontFiles`
  language range is present. That is why the generated file includes every common language with
  `0x0000 0xFFFF`; without it, Chinese text looks like Tahoma and the mod seems not to work.
- `--no-range` / `-NoRange` removes those range blocks on purpose: the font is then used for
  `0x0000–0x00FF` and other characters fall back to a system font (Tahoma on Windows,
  WenQuanYi Zen Hei on Linux).
- On Windows the family name must match what GDI's ANSI APIs report. Prefer the en-US name. If a
  localized name fails, force it:

  ```bat
  tools\set-font.cmd "C:\Fonts\YourCJK.ttf" -Name "zihunbudingti"
  ```

  ```bash
  ./tools/set-font.sh ~/Desktop/YourCJK.ttf --name zihunbudingti
  ```

  The font does **not** need to be installed system-wide or registered with `fc-cache`; the engine
  reads it from the mod folder. If the font file only contains a localized name, add an English
  family name in FontForge.

---

## Troubleshooting (quick)

| Symptom | Fix |
| --- | --- |
| Nothing changed | Check `tf/custom/!000_customfont/resource/clientscheme.res`; make sure no earlier-sorting folder has a `clientscheme.res`; with a HUD, run `--hud`; restart TF2; verify the family name |
| Nothing changed with a HUD | The HUD's scheme is shadowing the mod. Run `--hud` (it renames the HUD scheme), or rename `clientscheme.res` to `clientscheme_OLD.res` manually |
| Boxes / blank text | Font lacks the glyphs, or the family name is wrong; use a wider font or `-Name` |
| Chinese becomes Tahoma | `range` blocks are missing (e.g. `--no-range`); regenerate without `--no-range` |
| Want the original HUD/damage numbers | Add `--keep numbers` (Windows: `-Keep numbers`); `numbers` covers the `Team Fortress` family |
| Icons / scrollbar arrows missing | Do not replace `Marlett`, `Icons`, `tf2icons`, crosshair fonts; re-run the script to restore |
| HUD colours reverted | Re-run with `--hud` / `-Hud` |
| HUD looks broken after `--hud` | Restore, update the HUD, re-run `--hud`; check the load-order warning |
| Server browser unchanged | Engine dialogs use `resource/sourcescheme.res`, which this mod intentionally leaves alone |
| No bold text | The font file only contains one weight |
| Linux name detection fails | Install `fontconfig` or `pip install fonttools` |

VAC: this is a client-side UI mod, like a custom HUD; it does not modify game logic. Server-side
`sv_pure` rules are the only thing that could matter, and HUD resources are normally allowed.

Uninstall: if you used `--hud`, run `--restore` first, then delete
`tf/custom/!000_customfont` and restart TF2.

---

## License

- Scripts and documentation: MIT.
- `tools/fonts/DejaVuSans.ttf`: DejaVu Fonts, Bitstream Vera license
  (`tools/fonts/LICENSE-DejaVu.txt`).
- `tools/base/*.res`: extracted from Team Fortress 2, © Valve; included only as a compatibility
  base.

Credits: `andy013/votehud_custom_font`, `JarateKing/TF2-Hud-Reference`, Valve Source SDK.
