# TF2 自定义字体 Mod（!000_customfont）

一个客户端侧的《军团要塞 2》（Team Fortress 2）Mod，用来把游戏内显示的字体替换成你喜欢的任意
TrueType / OpenType 字体。支持按 TF2 的四类原始字体（`TF2`、`TF2 Build`、`TF2 Secondary`、
`TF2 Professor`）分别指定不同字体文件，也支持整体替换。支持 Windows 与 Linux，附带两个脚本：
自动读取字体文件里的**字体家族名**，并把 Mod 文件改好。

> 只改客户端界面（HUD、聊天、菜单、击杀提示等），不改游戏逻辑，不进入 `sv_pure` 判定之外的玩法数据，
> 性质与普通自定义 HUD 相同。

## 30 秒快速开始

1. 运行脚本，把 Mod 换成你的字体：
   - **Windows**：`tools\set-font.cmd "C:\路径\你的字体.ttf"`
   - **Linux**：`chmod +x tools/set-font.sh && ./tools/set-font.sh ~/路径/你的字体.ttf`
2. 把整个 `tf/custom/!000_customfont` 文件夹复制到游戏的 `tf/custom/` 下（详见第 4 节）。
   如果装了自定义 HUD，脚本要加 `--hud "<...>/tf/custom/你的HUD"`（详见第 7 节）。
3. 启动游戏。自定义字体文件在启动时注册，改字体后建议重启；`hud_reloadscheme` 只能重载 HUD 布局。

不想换字体也可以直接用自带的 DejaVu Sans，只做第 2 步即可。

如果想让不同种类的文字用不同字体（例如 `TF2 Build` / `TF2 Secondary` 用 `1.ttf`，
`TF2` / `TF2 Professor` 用 `2.ttf`），见 [5.5 按角色分别使用不同字体](#55-按角色分别使用不同字体)。

---

## 目录

- [1. 特性](#1-特性)
- [2. 工作原理](#2-工作原理)
- [3. 目录结构](#3-目录结构)
- [4. 安装](#4-安装)
- [5. 更换字体（推荐：脚本）](#5-更换字体推荐脚本)
- [6. 手动修改（不使用脚本）](#6-手动修改不使用脚本)
- [7. 与自定义 HUD 共存](#7-与自定义-hud-共存)
- [8. 调整字号、粗细与字体宽度](#8-调整字号粗细与字体宽度)
- [9. 中文 / 俄文 / 日文等多语言](#9-中文--俄文--日文等多语言)
- [10. 常见问题 FAQ](#10-常见问题-faq)
- [11. 卸载与恢复](#11-卸载与恢复)
- [12. 技术参考](#12-技术参考)
- [13. 许可与致谢](#13-许可与致谢)

---

## 1. 特性

- 替换 `resource/clientscheme.res` 里全部**文本字体**（HUD 主字体、计分板、目标 ID、击杀提示、
  任务面板、商店、回放、主菜单等，共 155 个字体族、229 个字形集）。
- **按 TF2 原始字体分组换字体**：`TF2`、`TF2 Build`、`TF2 Secondary`、`TF2 Professor` 四类
  可以各用不同文件；正文（Verdana/Arial/Tahoma…）、HUD 数字（`Team Fortress`）、自定义 HUD
  专属字体也各自独立。任意角色都可以选择保留原版字体。
- 额外替换 `resource/chatscheme.res`，聊天框与聊天输入框也使用新字体。
- 使用 `#base` 只覆盖字体名：颜色、边框、字号、粗细、阴影等全部沿用原方案（包括自定义 HUD 的方案）。
- 自动跳过图标/符号字体（`Marlett`、`Icons`、手柄按键位图字体），避免滚动条箭头、兵种图标
  变成空白方块。
- 附带的 `DejaVu Sans` 为默认字体，开箱即用；可直接换成任意字体。
- Windows（`set-font.cmd` + PowerShell）与 Linux（`set-font.sh`）脚本：
  - 读取 TTF/OTF 的真实字体家族名；
  - 复制字体到 Mod 目录（多字体时按角色命名，如 `customfont_tf2.ttf`）；
  - 用模板重新生成 `clientscheme.res` / `chatscheme.res`，按每个字形集的原始字体角色
    （`CUSTOMFONT:ORIG`）替换对应的字体；
  - 可选：每个角色单独指定字体，或让某个角色保留原版字体；
  - 可选：把自定义 HUD 的方案作为基础合并进来；
  - 可选：关闭全 Unicode 范围（让缺少 CJK 字形的字体回退到系统字体）。

---

## 2. 工作原理

TF2 的字体由 VGUI 的 **scheme** 文件定义，核心是两份文件：

```
Team Fortress 2/tf/resource/clientscheme.res   HUD、菜单、大部分游戏界面
Team Fortress 2/tf/resource/chatscheme.res     聊天框
```

每个字体定义长这样：

```res
Fonts
{
    "HudFontSmall"
    {
        "1"
        {
            "name"      "TF2 Secondary"   // ← 字体家族名
            "tall"      "12"              // 字号（随分辨率缩放）
            "weight"    "500"
            "antialias" "1"
        }
    }
}
```

自定义字体文件则在 `CustomFontFiles` 段注册：

```res
CustomFontFiles
{
    "1000"   // 键名任意，只要不和 HUD 已有的键冲突；HUD 的准星常用 "100"
    {
        "font" "resource/customfont.ttf"   // 字体文件路径
        "name" "DejaVu Sans"               // 注册名，必须等于字体家族名
        "english" { "range" "0x0000 0xFFFF" }
        ...
    }
}
```

本 Mod 的文件只做两件事：

1. 在 `CustomFontFiles` 里注册你的字体；
2. 用 `#base` 引入原版（或 HUD）的完整方案，然后把每个字体块的 `"name"` 覆盖成你的字体家族名。

`#base` 的合并规则是「当前文件优先、缺失的键从被包含文件补齐」，并且会**递归合并同名块**，
所以：

```res
#base "clientscheme_base.res"   // 原版完整方案

Scheme
{
    Fonts
    {
        "HudFontSmall"
        {
            "1" { "name" "DejaVu Sans" }   // 只改名字，tall/weight/... 自动继承
        }
    }
}
```

不会破坏 HUD 的颜色、边框和字号。

> **为什么 `"name"` 必须写字体家族名（Family Name）？**
>
> - Windows：引擎调用 GDI 的 `AddFontResourceEx` 注册字体文件，再用 `CreateFontA` 按**家族名**
>   创建字体。名字对不上就会退回系统字体。
> - Linux：引擎用 FreeType 直接读取文件，并以 `"name"`（去掉空格和连字符后）作为缓存的键；
>   `"name"` 对不上同样找不到字体。
>
> 因此两个平台的共同解法就是：`"name"` 一律填字体文件里的家族名。脚本会自动读取它。

---

## 3. 目录结构

```
customfont/
├── README.md                       本文件
├── README.en.md                    English quick guide
├── tf/
│   └── custom/
│       └── !000_customfont/         ← 实际要安装的 Mod
│           ├── info.vdf
│           └── resource/
│               ├── clientscheme.res       字体覆盖文件（自动生成）
│               ├── clientscheme_base.res  原版 / HUD 完整方案（基础）
│               ├── chatscheme.res         聊天字体覆盖文件（自动生成）
│               ├── chatscheme_base.res    原版 / HUD 聊天方案（基础）
│               ├── customfont.ttf         当前字体（单字体时）
│               └── customfont_<角色>.ttf  多字体时每个角色/家族一个文件
└── tools/
    ├── set-font.cmd                Windows 入口（双击或命令行）
    ├── set-font.ps1                Windows 实际逻辑（PowerShell 5.1+）
    ├── set-font.sh                 Linux/macOS 入口
    ├── base/
    │   ├── clientscheme.res        原版方案备份（脚本用它重置基础文件）
    │   └── chatscheme.res
    ├── template/
    │   ├── clientscheme.res        带占位符的覆盖模板
    │   └── chatscheme.res
    ├── fonts/
    │   ├── DejaVuSans.ttf          默认字体
    │   └── LICENSE-DejaVu.txt
    └── dev/
        ├── build-templates.py      从 base 重新生成模板（维护者用）
        ├── hud_scheme.py           复制 HUD scheme、按角色重映射字体、注入 HUD 字体
        └── verify.py               校验 #base 合并与角色映射结果（维护者用）
```

> `!000_` 前缀不是装饰。`gameinfo.txt` 把 `tf/custom/*` 里的每个子文件夹按**名称升序**加入搜索路径，
> 而 Source 查找文件时**第一个匹配的路径获胜**——也就是说，**名称靠前的文件夹优先级更高**。
> `!`（0x21）排在字母和 `-` 之前，所以 `!000_customfont` 会优先于 `-middle-mann`、`mastercomfig`、
> `workshop` 等常见文件夹。若你还有更靠前的 `!0000_...` 文件夹，需要相应调整名称。
>
> 这也解释了一个常见现象：HUD 自带的 `clientscheme.res` 会挡住单独安装的字体 Mod。
> 带 HUD 时请使用 `--hud` / `-Hud`，脚本会把 HUD 的 scheme 移开并复制为 Mod 的基础方案（见第 7 节）。

---

## 4. 安装

### 4.1 Windows

1. 把压缩包解压到任意位置。
2. 找到 TF2 安装目录，默认类似：

   ```
   C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\
   ```

   如果不确定：Steam 库 → 右键 Team Fortress 2 → 管理 → 浏览本地文件。
3. 把整个 `tf\custom\!000_customfont` 文件夹复制到：

   ```
   ...\Team Fortress 2\tf\custom\!000_customfont
   ```

   复制完成后应存在 `...\tf\custom\!000_customfont\resource\clientscheme.res`。
4. 启动 TF2。若游戏已经开着，在控制台输入 `hud_reloadscheme` 也可以立即重载（不必重启）。
5. **如果装了自定义 HUD**，不要只复制文件夹：先按第 7 节运行一次 `-Hud`，否则 HUD 的
   `clientscheme.res` 会挡住字体 Mod，或者字体生效但 HUD 颜色丢失。

### 4.2 Linux（含 Steam Deck / Flatpak）

常见安装目录：

| 安装方式 | 路径 |
| --- | --- |
| 发行版包管理器 / 官方 Steam | `~/.steam/steam/steamapps/common/Team Fortress 2/` |
| 官方 Steam（新路径） | `~/.local/share/Steam/steamapps/common/Team Fortress 2/` |
| Flatpak | `~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Team Fortress 2/` |
| Steam Deck | `/home/deck/.local/share/Steam/steamapps/common/Team Fortress 2/` |

```bash
cp -r tf/custom/!000_customfont \
      ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/
```

然后启动游戏，或在控制台执行 `hud_reloadscheme`。如果装了自定义 HUD，先按第 7 节运行
`./tools/set-font.sh 字体.ttf --hud "<...>/tf/custom/你的HUD"`。

> 不需要把字体安装到系统里，也不需要运行 `fc-cache`；引擎会直接读取 Mod 目录里的字体文件。

### 4.3 验证是否生效

- 主菜单、HUD 数字、计分板、聊天文字应该已经变成新字体。
- 控制台输入 `hud_reloadscheme` 可强制重载 HUD 字体（若字体文件被替换过，建议重启游戏）。
- 如果完全没变化，见 [FAQ](#10-常见问题-faq)。

---

## 5. 更换字体（推荐：脚本）

### 5.1 Windows

在解压目录中打开命令提示符或 PowerShell：

```bat
tools\set-font.cmd "C:\Users\你\Downloads\Inter.ttf"
```

也可以直接把字体文件**拖到 `tools\set-font.cmd` 上**。

带自定义 HUD 时：

```bat
tools\set-font.cmd "C:\Users\你\Downloads\Inter.ttf" -Hud "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\custom\flawhud"
```

| 参数 | 说明 |
| --- | --- |
| `-Font 角色=文件` | 给某个角色单独指定字体；多个角色写在一个引号参数里，例如 `-Font "tf2=2.ttf,build=1.ttf"`（PowerShell 不允许同名参数重复）。`-Font all=文件` 等于位置参数。角色见 [5.5](#55-按角色分别使用不同字体) |
| `-Keep 角色[,角色]` | 让该角色保留原版字体，例如 `-Keep numbers` 或 `-Keep "numbers,hud"` |
| `-ListFonts` | 列出可指定的角色与对应原版字体 |
| `-Name "名称"` | 手动指定字体家族名（自动识别失败、或需要 ASCII 别名时用）；`-Name "角色=名称"` 只覆盖该角色，多个角色写在一个引号参数里 |
| `-Hud <路径>` | 递归复制 HUD 的 scheme 依赖树，并把 HUD 同名 scheme 改名避让；保留颜色、布局和专属文本字体 |
| `-Restore` | 撤销 `-Hud`，把 HUD 的 `clientscheme.res` / `chatscheme.res` 改回去 |
| `-NoRange` | 不把字体强制用于全 Unicode 范围（纯拉丁字体想让中日韩文字回退系统字体时用） |
| `-Target <路径>` | 直接修改已安装的 Mod 目录，而不是解压目录里的 `tf/custom/!000_customfont` |
| `-Help` | 显示帮助 |

示例：

```bat
tools\set-font.cmd "C:\Windows\Fonts\comic.ttf" -Name "Comic Sans MS"

:: 所有角色使用同一个字体，但保留 HUD 数字（Team Fortress）
tools\set-font.cmd "C:\Fonts\Inter.ttf" -Keep numbers

:: 按角色分别指定（四类原始字体各用不同文件；多个 -Font 项写在一个引号参数里）
tools\set-font.cmd -Font "tf2=C:\Fonts\2.ttf,build=C:\Fonts\1.ttf,secondary=C:\Fonts\1.ttf,professor=C:\Fonts\2.ttf"
```

> 注意：`C:\Windows\Fonts` 里的文件可能受系统保护，建议先把字体复制到桌面/下载目录再运行。
>
> 脚本通过 `powershell.exe -ExecutionPolicy Bypass` 运行，一般不会被执行策略拦截；如果公司电脑
> 有额外策略，可手动运行：
>
> ```bat
> powershell -NoProfile -ExecutionPolicy Bypass -File tools\set-font.ps1 "C:\path\font.ttf"
> ```

### 5.2 Linux

从压缩包解压后，可执行位可能丢失，先补上：

```bash
chmod +x tools/set-font.sh
```

然后：

```bash
./tools/set-font.sh ~/Downloads/Inter.ttf
```

带 HUD：

```bash
./tools/set-font.sh ~/Downloads/Inter.ttf \
    --hud ~/.steam/steam/steamapps/common/"Team Fortress 2"/tf/custom/flawhud
```

| 参数 | 说明 |
| --- | --- |
| `--font 角色=文件` | 给某个角色单独指定字体，可重复；角色见 [5.5](#55-按角色分别使用不同字体)。`--font all=文件` 等于位置参数 |
| `--keep 角色[,角色]` | 让该角色保留原版字体，例如 `--keep numbers` 或 `--keep numbers,hud` |
| `--list-fonts` | 列出可指定的角色与对应原版字体 |
| `--name "名称"` | 手动指定字体家族名；`--name 角色=名称` 只覆盖该角色 |
| `--hud <路径>` | 递归复制 HUD 的 scheme 依赖树，并把 HUD 同名 scheme 改名避让；保留颜色、布局和专属文本字体 |
| `--restore` | 撤销 `--hud`，把 HUD 的 `clientscheme.res` / `chatscheme.res` 改回去 |
| `--no-range` | 关闭全 Unicode 范围 |
| `--target <路径>` | 直接修改已安装的 Mod 目录 |
| `--help` | 显示帮助 |

示例：

```bash
# 所有角色使用同一个字体，但保留 HUD 数字（Team Fortress）
./tools/set-font.sh ~/Downloads/Inter.ttf --keep numbers

# 按角色分别指定
./tools/set-font.sh --font tf2=~/Fonts/2.ttf --font build=~/Fonts/1.ttf \
    --font secondary=~/Fonts/1.ttf --font professor=~/Fonts/2.ttf
```

### 5.3 脚本具体做了什么

1. 读取字体的**家族名**：
   - Windows：GDI+ 的 `PrivateFontCollection`（与游戏使用 GDI 的命名一致）；
   - Linux：`fc-scan` / `fc-query`，没有 fontconfig 时用 Python `fontTools`，再不行就用文件名。
2. 把字体复制为 `tf/custom/!000_customfont/resource/customfont.<扩展名>`；如果角色使用了
   多个不同字体文件，则按第一个使用它的角色命名，例如 `customfont_tf2.ttf`、
   `customfont_build.ttf`。
3. 把 `tools/base/` 的方案复制为 `*_base.res`；如果指定了 `--hud`，则递归复制 HUD 的
   整棵 `#base` 依赖树，并把 HUD 的同名 scheme 改名为 `*_customfont_original.res` 避让。
4. 用 `tools/template/*.res` 生成正式的 `clientscheme.res` / `chatscheme.res`：
   先在 `CustomFontFiles` 里为每个唯一字体家族注册一条（键从 `1000` 递增），
   再按每个字形集的原始字体（模板里的 `// CUSTOMFONT:ORIG=...`）查角色表，
   写成该角色选定的字体名。保留角色继续使用原版家族名。
5. 带 HUD 时把 HUD 专属文本字体也加入覆盖（图标/符号字体跳过）。
6. 打印角色映射、安装提示和加载顺序警告。

脚本不会自动把文件复制进 Steam 目录（除非你用 `--target` 指向已安装目录），这样你可以先改好再安装，
也可以反复试用不同字体。

### 5.4 再换回默认字体

```bash
# Linux
./tools/set-font.sh tools/fonts/DejaVuSans.ttf
```

```bat
:: Windows
tools\set-font.cmd tools\fonts\DejaVuSans.ttf
```

### 5.5 按角色分别使用不同字体

TF2 用四种原始字体绘制不同位置的文字。脚本把它们以及其余正文/数字字体分成 7 个**角色**，
每个角色可以指向不同字体文件，也可以保留原版字体：

| 角色 | 对应原始家族 | 主要影响 |
| --- | --- | --- |
| `tf2` | `TF2` | 主菜单标题、HUD 大字、部分计分板/回放标题 |
| `build` | `TF2 Build` | 粗体 HUD、物品名、商店、匹配界面 |
| `secondary` | `TF2 Secondary` | 小号 HUD、计分板、按钮/提示文字 |
| `professor` | `TF2 Professor` | 黑板、任务/战役文本 |
| `body` | `Verdana`、`Arial`、`Tahoma`、`Trebuchet MS`、`OCR A Extended` 等 | 默认正文、聊天、提示、控制台覆盖层 |
| `numbers` | `Team Fortress` | HUD 数字、弹药/伤害数字 |
| `hud` | 只有自定义 HUD 才定义的家族（如 `G_FontSmall`） | 配合 `--hud` 时生效 |

`tf2build`、`tf2secondary`、`tf2professor` 是 `build`、`secondary`、`professor` 的别名。

**例：`TF2 Build` + `TF2 Secondary` 用 `1.ttf`，`TF2` + `TF2 Professor` 用 `2.ttf`**

```bat
:: Windows（多个 -Font 项写在一个引号参数里）
tools\set-font.cmd -Font "build=C:\Fonts\1.ttf,secondary=C:\Fonts\1.ttf,tf2=C:\Fonts\2.ttf,professor=C:\Fonts\2.ttf"
```

```bash
# Linux
./tools/set-font.sh --font build=~/Fonts/1.ttf --font secondary=~/Fonts/1.ttf \
    --font tf2=~/Fonts/2.ttf --font professor=~/Fonts/2.ttf
```

**例：整体用一个字体，但保留 HUD 数字**

```bash
./tools/set-font.sh ~/Downloads/Inter.ttf --keep numbers
```

```bat
tools\set-font.cmd C:\Fonts\Inter.ttf -Keep numbers
```

**例：默认字体 + 少量角色特殊处理**

```bash
./tools/set-font.sh ~/Downloads/Inter.ttf \
    --font tf2=~/Fonts/2.ttf --font professor=~/Fonts/2.ttf --keep numbers
```

规则：

- 显式写了 `--font` / `-Font` 的角色优先；没有单独指定、也没有 `--keep` 的角色使用
  位置参数（默认字体）；再没有就保留原版。
- `--keep` / `-Keep` 的角色保持原版家族名（例如伤害数字仍是 `Team Fortress`）。
- 同一个字体文件可以用于多个角色，脚本只会复制一份、在 `CustomFontFiles` 里注册一次
  （引擎按家族名索引，同一家族名不能注册两次）。
- 两个角色使用不同的字体**文件**但家族名相同时，脚本会警告并使用第一个文件。
- `--list-fonts` / `-ListFonts` 可以随时查看角色列表；不需要 Python 也能使用，
  但**按角色分配不同字体或保留角色**需要 Python 3（脚本内部的 `tools/dev/hud_scheme.py`
  负责按实际基础方案重映射字体名）。

---

## 6. 手动修改（不使用脚本）

适合想自己控制每一个细节、或脚本环境不可用的情况。

1. **取得字体家族名**

   Windows（PowerShell）：

   ```powershell
   Add-Type -AssemblyName System.Drawing
   $p = New-Object System.Drawing.Text.PrivateFontCollection
   $p.AddFontFile("C:\path\to\font.ttf")
   $p.Families[0].Name
   ```

   也可以双击字体文件，在预览窗口标题栏看到家族名。

   Linux：

   ```bash
   fc-scan --format '%{family[0]}\n' /path/to/font.ttf
   ```

2. **放入字体文件**

   把字体复制为：

   ```
   tf/custom/!000_customfont/resource/customfont.ttf
   ```

   如果字体是 `.otf`，可以命名为 `customfont.otf`（此时第 4 步要改路径）。

   如果用多个字体，建议按角色命名，并为每个家族在 `CustomFontFiles` 里各注册一条：

   ```res
   CustomFontFiles
   {
       "1000" { "font" "resource/customfont_build.ttf" "name" "Font One" ... }
       "1001" { "font" "resource/customfont_tf2.ttf"   "name" "Font Two" ... }
   }
   ```

3. **替换字体名**

   用文本编辑器打开：

   ```
   tf/custom/!000_customfont/resource/clientscheme.res
   tf/custom/!000_customfont/resource/chatscheme.res
   ```

   在文件开头的 `CustomFontFiles` 块里可以看到当前使用的名字，例如：

   ```res
   "font"  "resource/customfont.ttf"
   "name"  "DejaVu Sans"
   ```

   用「全部替换」把所有的 `"DejaVu Sans"` 换成你的新家族名（注意保留引号）。
   两个文件都要改。这只适用于“所有角色同一个字体”。

   如果想让不同角色用不同字体，不要全部替换，而是按每行末尾的原始字体注释逐行修改：

   ```res
   "1" { "name" "Font One" }   // CUSTOMFONT:ORIG=TF2 Build
   "1" { "name" "Font Two" }   // CUSTOMFONT:ORIG=TF2
   "1" { "name" "Verdana" }    // CUSTOMFONT:ORIG=Verdana   ← 保留原版
   ```

   `CUSTOMFONT:ORIG` 记录该字形集原本使用的家族；没有注释的行会直接继承基础方案。
   手动改完后，`"name"` 必须存在于 `CustomFontFiles` 的某个 `"name"` 注册项中。

4. **扩展名不是 .ttf 时**

   把 `"font" "resource/customfont.ttf"` 改成实际文件名，例如
   `"font" "resource/customfont.otf"`。

5. **重载**

   保存后启动游戏，或在控制台执行 `hud_reloadscheme`。

> 手动改过的文件会在下次运行脚本时被重新生成覆盖。如果需要长期保留手动调整，请改
> `tools/template/*.res`（脚本每次都从模板生成）。
>
> 编辑器请使用 **UTF-8（无 BOM）** 或系统 ANSI 编码保存；不要保存成带 BOM 的 UTF-8，
> 否则文件第一个键可能解析失败。

---

## 7. 与自定义 HUD 共存

### 7.1 为什么“只装字体 Mod”对 HUD 没用

`tf/custom/*` 的搜索顺序是**名称升序、第一个匹配获胜**。HUD 自带一份
`resource/clientscheme.res`，所以：

- 如果字体 Mod 叫 `zzz_customfont`，它排在 `-middle-mann-v26` 后面，
  **HUD 的 scheme 先被找到**，字体 Mod 的 scheme 根本不会被读取 → 字体完全不变。
- 如果字体 Mod 叫 `!000_customfont`，它会先于 HUD 被找到，字体能生效；
  但此时用的是原版基础方案，HUD 的颜色、边框、专属字体会丢失。

所以“带 HUD”不是简单换个文件夹名，而是要把 HUD 的完整方案作为基础，同时**让 HUD 自己的同名
scheme 不再抢先**。

### 7.2 脚本做法（推荐）

```bash
./tools/set-font.sh 你的字体.ttf --hud "<...>/tf/custom/你的HUD"
```

脚本会：

1. 找到 `<HUD>/resource/clientscheme.res`（或 `chatscheme.res`）。
2. 沿着文件里的 `#base` / `#include` **递归复制整棵依赖树**到
   `!000_customfont/resource/`，保持相对路径不变。顶层文件改名为
   `clientscheme_base.res` / `chatscheme_base.res`。
3. 把 HUD 原来的 `clientscheme.res` 改名为
   `clientscheme_customfont_original.res`（`chatscheme.res` 同理），
   这样它就不会再遮住字体 Mod。**这是让字体真正生效的关键一步。**
4. 生成只覆盖字体名的 `clientscheme.res` / `chatscheme.res`。
5. 扫描 HUD 方案里新增的文本字体（例如 `G_FontSmall`、`G_FontMedium`），
   自动加入覆盖；图标、符号和准星字体仍会跳过。

HUD 的颜色、边框、布局、专属文本字体全部保留，只替换字体。

> Windows 的 `-Hud` 递归复制不依赖 Python；但“自动注入 HUD 专属文本字体”需要 Python 3。
> 没有 Python 时只替换原版字体族，HUD 专属字体（如 `G_FontSmall`）会保持原样。
>
> `--hud` 会修改 HUD 文件夹（改名，不是删除）。原文件保留为
> `*_customfont_original.res`，随时可以用下面的命令还原：
>
> ```bash
> ./tools/set-font.sh --restore --hud "<...>/tf/custom/你的HUD"
> ```

### 7.3 手动方式

如果你不想用脚本，步骤与上面一致：

1. 把 HUD 的 `clientscheme.res` **及其所有 `#base` 文件**按原相对路径复制到
   `!000_customfont/resource/`，顶层文件命名为 `clientscheme_base.res`。
   `chatscheme.res` 同理。
2. 把 HUD 的 `resource/clientscheme.res` 改名为
   `clientscheme_customfont_original.res`，`chatscheme.res` 同理。
3. 按第 6 节修改 `!000_customfont/resource/clientscheme.res` / `chatscheme.res` 的字体名。
4. 如果 HUD 有专属字体名，按第 7.4 节补上。

### 7.4 注意事项

- **HUD 更新后**：先 `--restore`，更新 HUD，再重新运行 `--hud`。否则 `*_base.res` 还是旧版方案。
- **换回原版基础**：不带 `--hud` 运行一次脚本，会从 `tools/base/` 复制原版方案；
  如果之前用过 `--hud`，记得先 `--restore` 把 HUD 的 scheme 改回去。
- **分享 Mod 时**：`--hud` 改的是本机 HUD 文件夹，复制 `!000_customfont` 到别的机器并不能还原
  那台机器上的 HUD scheme；需要在目标机器上重新运行 `--hud`。
- 脚本会自动替换 HUD 新增的**文本**字体；`tf2icons`、`Marlett`、准星字体（`Size:...`）等
  不会替换，避免图标/准星损坏。
- 若还有别的文件夹排在 `!000_customfont` 之前并带有 `clientscheme.res`，脚本会给出警告。
  把那个文件夹改名，或把本 Mod 改成更靠前的名字（例如 `!0000_customfont`）。

---

## 8. 调整字号、粗细与字体宽度

不同字体的字面大小差异很大，换字体后可能出现文字偏大/偏小、HUD 溢出。

- **字号**：每个字体块的 `"tall"` 控制像素高度（会按分辨率缩放）。想让某处小一点，把它改小 1–2。
- **粗细**：`"weight"`，常见值 `0`（常规）、`500`、`700`、`900`。自定义字体通常只有一个字重，
  所以改 `weight` 多数情况下不会产生真正加粗，只影响 GDI 选面。
- **整体缩放**：`"scalex"` / `"scaley"`（浮点，默认 1.0）可以横向/纵向拉伸；一般不用。
- **抗锯齿**：`"antialias" "1"` 让边缘平滑；像素字体建议设 `0`。

例子：把 HUD 主字体改小一号并去掉强制粗体：

```res
"HudFontSmall"
{
    "1" { "name" "DejaVu Sans" "tall" "11" "weight" "0" }
}
```

> 直接在 `tf/custom/!000_customfont/resource/clientscheme.res` 里改是临时效果，重新运行脚本会覆盖。
> 想长期保留：把相同的键写进 `tools/template/clientscheme.res` 对应字体块（模板不会被脚本覆盖，
> 只会被 `tools/dev/build-templates.py` 覆盖）。

---

## 9. 中文 / 俄文 / 日文等多语言

### 9.1 字体必须包含对应字形

本 Mod 默认的 DejaVu Sans 覆盖拉丁、希腊、西里尔字母，但**不包含汉字/假名/韩文**。
如果你的游戏语言是中文，或经常看到中文玩家名，请换成包含这些字形的字体，例如：

- Noto Sans SC / Noto Sans CJK SC（开源）
- 思源黑体 / Source Han Sans（开源）
- 微软雅黑（Windows 自带，**不可再分发**）
- 更纱黑体 Sarasa Gothic（开源，含等宽变体）

### 9.2 `range` 的作用

`CustomFontFiles` 里的语言块告诉引擎「这个字体负责哪个 Unicode 范围」：

```res
"english"  { "range" "0x0000 0xFFFF" }
"schinese" { "range" "0x0000 0xFFFF" }
```

- **默认（保留 range）**：引擎把整个 Unicode 范围都交给你的字体，适合自带 CJK 字形的字体。
- **`--no-range` / `-NoRange`**：删掉这些语言块，引擎只把 `0x0000–0x00FF` 交给你的字体，
  其余字符回退到系统字体（Windows 上是 Tahoma，Linux 上是 WenQuanYi Zen Hei 等）。
  适合「只换英文界面、中文名想用系统字体显示」的情况。

> 如果**保留 range** 而字体本身没有 CJK 字形，中文会显示为方框或空白；此时请换用含 CJK 的字体，
> 或使用 `--no-range` 让系统字体接管非拉丁字符。

### 9.3 Windows、Tahoma 与“中文家族名”

Windows 上引擎的字体选择逻辑（`CFontManager::SetFontGlyphSet`）有一个容易踩的坑：

- 如果字体不在引擎的“亚洲字体白名单”里，**且** `CustomFontFiles` 没有为当前游戏语言设置
  `range`，那么 `0x0000–0x00FF` 之外的字符会强制交给 **Tahoma**。
- 所以只改 `Fonts` 里的 `"name"` 而不写 `range`，中文界面会变成 Tahoma，看起来像“没生效”。
- 本 Mod 默认给所有常见语言写 `0x0000 0xFFFF`，让引擎把你的字体用于整个 Unicode 范围。
  只有在你**故意**想让中文回退系统字体时，才用 `--no-range` / `-NoRange`。

另一个坑是**家族名**：

- Windows 的 `AddFontResourceExA` / `CreateFontA` 使用 ANSI 接口，对本地化中文家族名
  （例如“字魂布丁体(商用需授权)”）不一定能正确匹配。
- 字体文件通常同时包含英文名（例如 `zihunbudingti`）和中文名。优先使用**英文名**。
  本项目的 Windows 脚本会用 GDI+ 的 `GetName(0x0409)` 取 en-US 名称；Linux 脚本会优先读
  en-US 名称表。
- 如果自动识别到的仍是中文名，手动指定：

  ```bat
  tools\set-font.cmd "C:\字体\字魂布丁体.ttf" -Name "zihunbudingti"
  ```

  ```bash
  ./tools/set-font.sh ~/桌面/字魂布丁体.ttf --name zihunbudingti
  ```

- 字体**不需要**安装到系统，也不需要 `fc-cache`；引擎直接从 Mod 目录读取。但 Windows 上
  如果字体文件本身的 name 表只有中文名，建议用 FontForge 增加一个英文家族名后再用。

### 9.4 显示为方框的排查

1. 字体是否真的包含该字符？（用 FontForge / `fc-query` 查看 charset）
2. 是否用了 `--no-range` 且字体没有 CJK 字形？
3. Windows 上家族名是否与系统/游戏识别的一致？（用 `-Name` 指定英文名试试）

---

## 10. 常见问题 FAQ

### Q1. 装好后字体完全没变？

按顺序检查：

1. **路径是否正确**：必须是
   `...\Team Fortress 2\tf\custom\!000_customfont\resource\clientscheme.res`，
   不是 `tf\custom\customfont\...`，也不要多套一层 `tf`。
2. **是否被更靠前的文件夹遮住**：`tf/custom` 按名称**升序**搜索，**第一个匹配获胜**。
   如果还有 `!0000_...` 之类的文件夹排在 `!000_customfont` 前面，并且带着
   `clientscheme.res`，本 Mod 就不会被读取。把那个文件夹改名，或把本 Mod 改成更靠前的名字。
   下划线本身不会导致不加载；`!000_customfont` 这种带下划线的名字是合法的。
3. **是否装了 HUD**：HUD 自带的 `clientscheme.res` 会抢在字体 Mod 前面。请用
   `--hud` / `-Hud` 运行脚本（见第 7 节），不要只把 Mod 文件夹改名。
4. **字体家族名是否匹配**：用脚本重新生成，或手动核对 `"name"`。
5. **是否重载**：`hud_reloadscheme`，或直接重启游戏（自定义字体文件通常在启动时注册）。
6. **验证 Mod 是否被加载**：在控制台输入 `path` 查看搜索路径；或在
   `tf/custom/!000_customfont/resource/` 里放一个明显的测试文件确认游戏读到了该目录。

### Q2. 文字变成方块/空白？

字体缺少对应字形，或 `"name"` 与字体家族名不一致。换一个覆盖范围更大的字体，或用 `-Name` 指定正确名称。
中文界面请使用含 CJK 的字体（见第 9 节）。

### Q3. 滚动条箭头、兵种图标、手柄按键图标坏了？

本 Mod 默认跳过：

- `Marlett` / `MarlettSmall`：窗口和滚动条符号字体；
- `Icons`：兵种/状态图标字体（`Team Fortress` 家族）；
- `GameUIButtons*`：手柄按键位图字体。

如果你把这几项也替换了，图标就会消失。不要替换它们。若你已经改坏，重新运行脚本即可恢复。

### Q4. 装了 HUD 之后颜色/布局变回原版？

没有使用 `--hud`，或者使用的是旧版脚本。带 HUD 时请按第 7 节运行：

```bash
./tools/set-font.sh 字体.ttf --hud "<...>/tf/custom/你的HUD"
```

它会递归复制 HUD 的完整方案，并把 HUD 自己的 `clientscheme.res` 改名为
`clientscheme_customfont_original.res`，避免原版基础方案覆盖 HUD 颜色。

### Q5. 主菜单变了，但服务器浏览器、设置窗口没变？

引擎级对话框使用 `resource/sourcescheme.res`，本 Mod **故意不覆盖**它，以免不同平台的条件字体
（`[$OSX]`、`[!$OSX]`）被错误合并。如果你确实想替换，可以自行复制一份
`resource/sourcescheme.res` 并用同样的方法加字体覆盖，但请自行承担兼容性风险。

### Q6. 开发者覆盖层（netgraph、`cl_showpos` 等）的字体也变了吗？

会。这些文字使用 `DebugOverlay` 字体，已被本 Mod 替换。建议搭配等宽字体（如 Sarasa Mono、
JetBrains Mono）；换成比例字体会让数字和文字的对齐变差。

开发者控制台本身由引擎绘制，本 Mod 未覆盖 `sourcescheme.res`，因此不保证控制台字体一定改变；
如果它跟随 scheme 的默认字体，则会一并变化。

### Q7. 会被 VAC 封禁吗？

不会。这是纯客户端 UI 资源修改，与自定义 HUD 同类，不修改游戏逻辑，也不注入进程。
在 `sv_pure 2` 服务器上，自定义 HUD 资源通常是被允许的；如果某个服务器有额外的限制，以该服务器为准。

### Q8. 游戏更新后失效/界面异常？

Valve 可能改动 `clientscheme.res`。本 Mod 的基础文件是某一版本的快照；更新后如果出现新界面缺字或
颜色异常，请刷新基础文件（见第 12.5 节），再运行一次脚本。

### Q9. 为什么没有粗体？

字体文件本身通常只有一个字重。Windows 下 GDI 只会在这个字体家族里选最接近的字重，不会凭空合成粗体；
Linux 下 FreeType 直接使用该文件。想要粗体效果，请使用同时包含 Regular/Bold 的字体家族，并在系统里
安装，或选择本身较粗的字体。

### Q10. 伤害数字（HudNumbers）也变了吗？

默认会。`HudNumbers` 等 HUD 数字使用 `Team Fortress` 家族，对应 `numbers` 角色。
若想保留原版数字/弹药外观，加 `--keep numbers`（Windows：`-Keep numbers`）：

```bash
./tools/set-font.sh 你的字体.ttf --keep numbers
```

这时只有 `Team Fortress` 的字形集保留原样，其余角色仍使用你的字体。
只删 `clientscheme.res` 里的 `"HudNumbers"` 块也行，但下次运行脚本会被重新生成覆盖。

### Q11. Linux 上脚本提示找不到字体家族名？

先安装 fontconfig 工具：

```bash
# Debian/Ubuntu
sudo apt install fontconfig
# Arch
sudo pacman -S fontconfig
# Fedora
sudo dnf install fontconfig
```

或者安装 Python 的 `fonttools`：

```bash
python3 -m pip install fonttools
```

脚本会自动依次尝试 `fc-scan` → `fc-query` → `fontTools` → 文件名。

### Q12. Linux 上字体生效但看起来和 Windows 不一样？

两个平台的字体光栅化器不同（GDI vs FreeType），字号取整、抗锯齿、行高会有细微差异，这是正常的。
可以微调 `"tall"` 或 `"antialias"`。

### Q13. Steam Deck 可以用吗？

可以。路径见 4.2。Steam Deck 的 TF2 是 Linux 版，使用 `set-font.sh`。

### Q14. 可以把字体文件共享给别人吗？

只共享你拥有分发权的字体。商业字体（微软雅黑、Comic Sans、SF Pro 等）不能随 Mod 一起分发；
让使用者自己准备字体文件即可。

---

## 11. 卸载与恢复

- **先撤销 HUD 修改（如果用过 `--hud`）**：

  ```bash
  ./tools/set-font.sh --restore --hud "<...>/tf/custom/你的HUD"
  ```

  这会把 `*_customfont_original.res` 改回 `clientscheme.res` / `chatscheme.res`。
- **卸载**：删除 `Team Fortress 2/tf/custom/!000_customfont` 整个文件夹，重启游戏。
- **恢复默认字体但保留 Mod**：运行脚本并传入 `tools/fonts/DejaVuSans.ttf`；带 HUD 时再加
  `--hud`。或删除 `clientscheme.res` / `chatscheme.res` / `*_base.res` / `customfont.*` 后重新运行。
- **恢复原版 HUD 方案**：不带 `--hud` 运行脚本（会从 `tools/base/` 复制原版）；如果之前用过
  `--hud`，先执行上面的 `--restore`，否则 HUD 的 scheme 仍处于改名状态。

## 12. 技术参考

### 12.1 覆盖的文件与字体数量

| 文件 | 覆盖字体族 | 覆盖字形集 |
| --- | --- | --- |
| `resource/clientscheme.res` | 155 | 229 |
| `resource/chatscheme.res` | 2（`Default`、`ChatFont`） | 10 |

跳过的字体：`Marlett`、`MarlettSmall`、`Icons`、`GameUIButtons*`。

按角色拆分字体时，覆盖的字体族/字形集数量不变，只是每个 `"name"` 来自该角色选定的字体；
保留的角色仍写原版家族名。`CustomFontFiles` 会为每个唯一字体家族注册一条（键 `1000`、`1001`…），
所以不同角色可以真的使用不同文件。

### 12.2 `#base` 的合并行为

Source 的 `KeyValues` 在解析 `#base` 时使用 `RecursiveMergeKeyValues`：

- 当前文件已有的键**优先**；
- 被包含文件独有的键会追加到当前键的后面；
- 同名块递归合并。

因此我们只需要写 `"name"`，其余键会从基础方案继承。字体块里的多个 `"1" "2" ...` 子块必须逐一覆盖，
因为引擎每个分辨率只会选中其中一个子块。

`tf/custom/*` 的顺序则来自 `tf/gameinfo.txt` 的通配符展开：目录与 VPK 按名称升序排序后依次
`AddSearchPath(..., PATH_ADD_TO_TAIL)`，而文件系统查找从搜索路径列表的第一条开始，所以
**名称靠前的文件夹先被匹配、优先级更高**。这就是 `!000_customfont` 必须排在 HUD 前面的原因。

### 12.3 自定义字体在 Windows 与 Linux 上的差异

| | Windows | Linux / macOS |
| --- | --- | --- |
| 加载方式 | `AddFontResourceExA` 注册到 GDI | FreeType `FT_New_Memory_Face` |
| 名称来源 | 字体文件内部的 GDI 家族名（优先 en-US） | `CustomFontFiles` 的 `"name"`，去掉空格和 `-` 后作为缓存键 |
| 未设 `range` 时 | `0x00FF` 以上回退 **Tahoma** | 回退系统字体（如 WenQuanYi Zen Hei） |
| 字体安装 | 不需要安装到系统 | 不需要 `fc-cache` |
| `"name"` 要求 | 必须能被 GDI 的 ANSI 接口匹配，优先英文家族名 | 必须与注册名一致（脚本两者填同一个值） |

这就是为什么脚本坚持使用**字体家族名**，而不是随意起别名；也是为什么中文界面必须保留
`0x0000 0xFFFF` 的 `range` 块。

### 12.4 语言 `range` 的取舍

TF2 的字体管理器会在以下情况把非拉丁字符交给备用字体：

- 字体名不在“亚洲字体白名单”里；
- 且 `CustomFontFiles` 没有为当前语言设置 range。

本 Mod 默认给所有常见语言设置 `0x0000 0xFFFF`，强制使用你的字体，从而支持中文/日文/韩文/俄文等。
`--no-range` 则恢复“拉丁字体 + 系统备用字体”的默认行为。

### 12.5 更新基础方案（游戏或 HUD 更新后）

需要工具：**VPKEdit**（Windows/Linux，开源）或 **GCFScape**（Windows）。

1. 打开 `Team Fortress 2/tf/tf2_misc_dir.vpk`。
2. 提取：

   ```
   resource/clientscheme.res
   resource/chatscheme.res
   ```

3. 覆盖本项目的：

   ```
   tools/base/clientscheme.res
   tools/base/chatscheme.res
   ```

4. 重新生成模板（需要 Python 3）：

   ```bash
   python3 tools/dev/build-templates.py
   python3 tools/dev/verify.py
   ```

5. 重新运行 `set-font.sh` / `set-font.cmd` 生成 Mod 文件。

> `tools/dev/build-templates.py` 会自动跳过图标/位图字体，并保留所有字体子块。
> `tools/dev/verify.py` 会模拟 `#base` 合并，检查每个字形集是否都被正确覆盖、角色映射是否正确、
> 颜色/边框是否保留。

### 12.6 文件格式说明

- `.res` 文件是 KeyValues 文本；本 Mod 的文件为 UTF-8（Linux 生成）或系统 ANSI（Windows 生成）。
- 行尾为 LF；Source 能正常解析。
- 字体路径使用正斜杠 `resource/customfont.ttf`，两个平台通用。

---

## 13. 许可与致谢

- 本项目的脚本与文档：MIT License。
- `tools/fonts/DejaVuSans.ttf`：DejaVu Fonts，Bitstream Vera 许可，见
  `tools/fonts/LICENSE-DejaVu.txt`。
- `tools/base/*.res`：从《军团要塞 2》游戏文件中提取的 VGUI 方案，版权归 Valve 所有，
  仅用于兼容性基础文件。
- 思路参考了社区 HUD 的字体替换方案，尤其是：
  - `andy013/votehud_custom_font`（`#base` + `CustomFontFiles` 的用法）
  - `JarateKing/TF2-Hud-Reference`（scheme 文件参考与文档）
  - Valve Source SDK（`KeyValues`、`Scheme`、`MatSystemSurface` 的加载逻辑）

---

## 已知限制

- 不同字体的字面尺寸不同，可能需要微调 `tall`；本项目不自动适配每个 HUD。
- HUD 专属的**图标/准星**字体不会被替换（见 7.4）；文本字体由 `--hud` 自动加入。
- 引擎级 `sourcescheme.res` 未覆盖（见 Q5）。
- 脚本与 `#base` 合并逻辑已在 Linux 上验证；实际游戏内的显示效果依赖具体字体与 HUD，
  建议换字体后进游戏检查计分板、目标 ID、聊天和主菜单。
