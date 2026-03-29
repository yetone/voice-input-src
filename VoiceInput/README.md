# VoiceInput - macOS 语音输入工具

一个优雅的 macOS 菜单栏语音输入工具，支持实时语音转文字和 LLM 智能修正。

## 系统要求

- **macOS 13.0+** (已兼容 macOS 13 和 14+)
- Xcode 14.3.1 或更高版本（包含 Swift 编译工具链）

## 安装步骤

### 1. 确保已安装 Xcode

打开 Mac App Store，搜索并安装 **Xcode**。对于 macOS 13.7.8，推荐安装：
- **Xcode 15.2**（支持 macOS 13.0+）
- 或 **Xcode 14.3.1**（支持 macOS 12.5+）

安装完成后，在终端运行：
```bash
xcode-select --install
```

### 2. 构建应用

进入项目目录并执行：
```bash
cd /path/to/VoiceInput
make build
```

这会在 `.build/release/` 目录下生成 `VoiceInput.app`。

### 3. 安装到应用程序文件夹

```bash
make install
```

这会将 `VoiceInput.app` 复制到 `/Applications/` 目录。

或者手动复制：
```bash
cp -r .build/release/VoiceInput.app /Applications/
```

### 4. 首次运行与权限设置

在「启动台」或「应用程序」文件夹中找到 **VoiceInput** 并打开。

**⚠️ 重要：您需要授予以下权限：**

1. **麦克风权限**：系统会弹出请求，点击「好」。
   - 若未弹出：`系统设置` > `隐私与安全性` > `麦克风`，勾选 VoiceInput

2. **语音识别权限**：系统会弹出请求，点击「好」。
   - 若未弹出：`系统设置` > `隐私与安全性` > `语音识别`，勾选 VoiceInput

3. **辅助功能权限**（用于模拟键盘输入）：
   - `系统设置` > `隐私与安全性` > `辅助功能`，添加并勾选 VoiceInput

## 使用方法

1. 安装完成后，菜单栏会出现 🎙️ 图标
2. **按住 `Fn` 键** 开始录音（显示悬浮胶囊窗口和声波动画）
3. **松开 `Fn` 键** 停止录音，自动转录并输入到当前光标位置
4. 点击菜单栏图标可进入 **设置**，配置：
   - 语言（简体中文、繁体中文、English、日本語、한국어）
   - LLM API Base URL
   - API Key
   - Model

## 功能特性

- ✅ Fn 键全局快捷键（抑制表情符号选择器）
- ✅ Apple Speech Recognition 实时流式识别
- ✅ 优雅胶囊形悬浮窗（56px 高度，28px 圆角）
- ✅ 实时音频波形（5 柱状，RMS 驱动，有机抖动效果）
- ✅ 平滑动画（弹簧入场 0.35s，文字过渡 0.25s，缩放退场 0.22s）
- ✅ 智能文本注入（剪贴板 + Cmd+V，CJK 输入法源检测）
- ✅ LLM 智能修正（保守纠错提示，修复同音词错误）
- ✅ LSUIElement 模式（仅菜单栏，无 Dock 图标）
- ✅ macOS 13 完全兼容

## 常见问题

**Q: 点击菜单栏图标没反应？**
A: 请检查是否已授予「辅助功能」权限。

**Q: 无法录音？**
A: 请检查「麦克风」和「语音识别」权限。

**Q: 如何卸载？**
A: 直接从 `/Applications/` 删除 `VoiceInput.app` 即可。

**Q: macOS 13 和 14 有什么区别？**
A: macOS 13 使用 `.contentBackground` 材质（视觉效果略有差异），macOS 14+ 使用 `.hudWindow` 材质。核心功能完全一致。

## 开发说明

### 项目结构
```
VoiceInput/
├── Package.swift          # Swift Package Manager 配置
├── Makefile               # 构建脚本
├── Info.plist             # 应用信息
├── Resources/             # 资源文件
└── Sources/VoiceInput/
    ├── VoiceInputApp.swift    # 应用入口
    ├── AppDelegate.swift      # 主逻辑（事件监听、语音识别、文本注入）
    ├── OverlayWindow.swift    # 悬浮窗口（波形动画、视觉效果）
    ├── AudioLevelMonitor.swift # 音频电平监测
    ├── InputSourceHelper.swift # 输入法源辅助
    └── SettingsWindow.swift   # 设置窗口
```

### 构建命令
```bash
# 开发构建
swift build

# Release 构建
swift build -c release

# 清理
make clean
```

## 许可证

MIT License
