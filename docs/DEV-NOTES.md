# 吾苍耳冯福 · WebView 套壳 APK

把「吾苍耳冯福」五字符编码器打包成一个可安装的 Android 应用。页面、字体、图标全部内嵌在
APK 里，**运行时零网络**，不依赖任何服务器或 CDN。

> 本文是中文技术笔记，偏维护向。想先了解这个应用本身，看根目录的 `README.md`；
> 完整的中英双语手册（原理、规格、功能、构建、更新日志）在 `MANUAL.txt`。

## 产物

| 文件 | 说明 |
|---|---|
| `wucangerfengfu.apk` | 构建产物，已签名可安装（约 1.8 MB）；不提交到仓库，发布时放 Releases |
| `app/assets/index.html` | 单文件页面（内联样式与脚本） |
| `app/assets/fonts/wcf-serif-{400,700}.otf` | 思源宋体子集，含 GB2312 一级字与页面用到的全部字符 |
| `app/src/com/wcf/editor/MainActivity.java` | WebView 壳 |
| `build.ps1` | 完整构建脚本（无需 Gradle） |
| `make-icon.ps1` | 生成五种密度的启动图标 |
| `subset-font.py` | 从 `_font/` 的源 OTF 生成上面两个子集字体 |

- 包名 `com.wcf.editor`，versionCode 7 / versionName 1.3.2
- minSdk 21（Android 5.0+），targetSdk 34
- 签名：v1 + v2 + v3 全部有效，debug 自签名

## 界面（v1.1.0 重做，v1.2.0 补平板，v1.3.0 补分享与字号，v1.3.1 去掉朱印，v1.3.2 零权限）

整本册子是一份**随身一次性密码本**：纸、墨、朱红三色，全篇宋体，密文按四个一组排成栅格，
全篇没有任何动效。没有渐变、没有阴影、没有 emoji，层级靠发丝线与字号。

- **编码器**：页眉册号 + 五字样本条（可点击插字）+ 明文区 + 编码/还原 + 密文栅格 +
  「复制」按钮。编码完按钮复制密文，还原完复制明文。
  - 屏幕 ≥820px 时册子**摊开成左右两页**：左页写、右页出密文，中缝是一条发丝竖线；
    手机与竖屏仍是单栏（520–819 用 620px 居中栏，≥820 用 1080px）。
- **公告**：关于（致谢 ChatGPT6、DeepSeek v4.1 Flash、聂某、徐某）、更新概述
  （v1.3.1 / v1.3.0 / v1.2.0 / v1.1.0 / v1.0.2 / v1.0.1 六条累积保留）。
- **存根**：历史记录，`NO.00N` 编号，支持载入、复制、**下载为 txt**、删除、两次点击清空。
  下载走 `ACTION_CREATE_DOCUMENT`，自己选目录，**不需要存储权限**。
- **夜间版 / 日间版**：顶部文字按钮切换，写入 `localStorage.wcf-theme`。
- **字号三档**（v1.3.0）：顶部「字号」按钮按 中→大→小 循环；全页 `font-size` 都由
  `--tz` 缩放（93% / 100% / 113%），写入 `localStorage.wcf-size`。
- **互通**（v1.3.0）：结果页眉「发给朋友」调系统分享面板；别的应用分享文字进来会
  落到本应用，像密文就还原、否则编码。
- **撤销**（v1.3.0）：清空、交换、删除存根、清空存根之后六秒内可撤销。
- **底部导航**：三栏瞬时切换，无滑动动画。

## 构建

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

工具链是 build-tools 34.0.0 + platform android-34（用 `$env:ANDROID_HOME` 指向 SDK），
不需要安装 Android Studio。构建流程是手工编排的 `aapt2 → javac → d8 → 打包 → zipalign → apksigner`，
不依赖 Gradle。

> **坑**：aapt2 在 Windows 上按原生分隔符写 asset 条目名，`assets/fonts/*.otf` 会变成
> `assets\fonts\*.otf`，Android 的 AssetManager 用 `/` 查找会 404、字体静默回退。
> `build.ps1` 第 5 步会在对齐签名之前把条目名里的 `\` 改回 `/`。

构建脚本末尾的退出码可能是 1：javac 的 deprecation 提示走 stderr，被 PowerShell 5.1 当成
`NativeCommandError`。构建本身是成功的，看 `== verify ==` 段即可。

## 布局上踩过的三个坑

改 `index.html` 的版面之前先看一眼，这三个都很难从截图上看出来：

1. **`left:50%` + `right:0` 不给 `width` 会塌**：底部导航想居中时写成
   `position:fixed; left:50%; right:0; transform:translateX(-50%); max-width:520px`，
   宽度会先按 `50%→100%` 算出视口一半，`max-width` 根本没机会生效。必须显式 `width:100%`。
2. **`html,body{height:100%}` 会让 body 变成独立滚动容器**：内容溢出时视口不滚、
   `documentElement.scrollHeight` 永远等于视口高。正确写法是 `html{height:100%}` +
   `body{min-height:100%}`。
3. **transform 动画的溢出会撑宽移动端视口**：曾经的朱印（v1.3.1 已删）从 `scale(1.6)` 起跳，动画期间 bbox
   越界会进入 scrollable overflow，手机浏览器随即把 layout viewport 加宽并整体缩放（而且是
   粘性的）。用 `transform-origin:100% 100%` 让它只往内长。排查时先看
   `document.documentElement.scrollWidth` 是否大于 `clientWidth`。

## 更换页面内容

替换 `app/assets/index.html` 后重新构建即可，壳代码不用动。改了文案就要重跑字体子集：

```powershell
pip install fonttools brotli
# 源字体放到 _font/（Noto Serif SC，SIL OFL 1.1）：
#   https://github.com/notofonts/noto-cjk/raw/main/Serif/SubsetOTF/SC/NotoSerifSC-Regular.otf
#   https://github.com/notofonts/noto-cjk/raw/main/Serif/SubsetOTF/SC/NotoSerifSC-Bold.otf
python subset-font.py
```

## 相对原页面的三处适配

原页面是给浏览器写的，有三处行为在 WebView 里会失效，壳里做了桥接：

1. **复制结果** — `navigator.clipboard.writeText` 在 `file://` 文档里可能被拒绝。
   注入的 shim 把本地剪贴板调用重定向到原生 `ClipboardManager`。
2. **不同意，退出应用** — 页面调 `window.close()`，WebView 会静默忽略。
   shim 将其映射到 `Activity.finish()`，按钮才会真正退出应用。
3. **存根下载为 txt** — `<a download>` 在 WebView 里不会真的落盘。页面优先调
   `AndroidShell.saveText(name, text)`，壳用 `ACTION_CREATE_DOCUMENT` 弹系统保存框；
   没有这个桥时（浏览器里调试）退回 Blob 下载。

其余逻辑（五进制编解码、`localStorage`、须知弹层）都是页面自身的 JS，壳只开了 JS 与
DOM Storage。

## 开发工具（`dev/`，不进 APK）

| 文件 | 用途 |
|---|---|
| `dev/probe.mjs` | 用 CDP 把页面塞进 390×844@2x 的模拟视口，执行脚本并截图 |
| `dev/_shot.js` | 截图场景脚本（editor / ink / announce / history / error / consent） |
| `dev/_measure.js` | 布局量化（`scrollWidth` 是否大于 `clientWidth`、关键盒子的 rect） |
| `dev/_smoke.js` | 功能回归（往返编码、三条错误文案、主题切换、存根） |

用法：先用 `--remote-debugging-port=9334` 起一个 `--headless=new` 的 Chrome，再

```powershell
$env:CDP_PORT='9334'; $env:CDP_FULL='1'
node dev/probe.mjs "<file:///.../app/assets/index.html>?cap=full#editor" 390 844 out.png dev/_shot.js
```

## 已知限制

- **未在真机运行验证**：本机没有 adb 也没有模拟器，只做了静态校验（签名、资源、dex、
  zipalign 对齐、asset 字节比对）与 Chromium 里的布局/功能回归。安装后如有异常请告诉我
  具体现象。
- 使用的是 debug 签名，自用/侧载没问题；若要上架或长期分发，建议用你自己的正式密钥
  重新签名（`apksigner sign --ks your.jks`）。
- 没有做自适应图标（adaptive icon），用的是普通方图图标；targetSdk 34 下系统可能自行
  加圆角遮罩。
