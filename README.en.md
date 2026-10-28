# TF2 Custom Font Mod (`!000_customfont`)

A client-side Team Fortress 2 mod that replaces the in-game fonts with any TrueType/OpenType
font you like. Works on Windows and Linux. Two helper scripts read the **font family name** from
the font file and patch the mod for you.

> Client-side UI only (HUD, chat, menus, kill feed). Same category as a custom HUD. No gameplay
> changes, no injection.

The full documentation is in Chinese in [README.md](README.md); this file is a compact English
guide covering the same workflow.

---

## What it does

- Overrides every text font in `resource/clientscheme.res` (155 families / 229 glyph sets):
  HUD, scoreboard, target ID, kill feed, contracts, store, replay, main menu, …
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
requires Python 3. Without Python, the vanilla families are still replaced, but HUD-only names such
as `G_FontSmall` keep their original font.

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
```

### Linux

```bash
chmod +x tools/set-font.sh          # zip extraction may drop the executable bit
./tools/set-font.sh ~/Downloads/Inter.ttf
./tools/set-font.sh ~/Downloads/Inter.ttf --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
./tools/set-font.sh ~/Downloads/Inter.ttf --name "Comic Sans MS"
./tools/set-font.sh ~/Downloads/Inter.ttf --no-range
./tools/set-font.sh ~/Downloads/Inter.ttf --target ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/!000_customfont
```

What the script does:

1. Reads the family name (`GDI+ PrivateFontCollection` with the en-US name on Windows,
   `fc-scan`/`fc-query`/`fontTools` on Linux).
2. Copies the font to `resource/customfont.<ext>`.
3. Copies the vanilla scheme, or the HUD's full `#base` tree with `--hud`.
4. Regenerates `clientscheme.res` / `chatscheme.res` from `tools/template/*.res`.
5. Prints the result and a load-order warning.

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
3. In **both** `resource/clientscheme.res` and `resource/chatscheme.res`, replace every occurrence
   of the current family name (see the `CustomFontFiles` block, key `"1000"`) with the new one.
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
