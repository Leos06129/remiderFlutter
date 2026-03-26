# 随机提醒 App — Flutter 跨平台版

同时支持 **Android APK** 和 **iOS IPA**，一套代码双端运行。

---

## 功能
- 🔔 每隔 **1~4 分钟**随机触发，锁屏状态下弹出提醒通知
- ✏️ 三行可编辑汉字提醒内容
- 💾 内容自动保存（重启后恢复）
- 📱 支持 Android 8.0+ / iOS 12+

---

## 一、本地构建（需要 Mac + Xcode）

### 1. 安装 Flutter SDK

```bash
# 访问 https://flutter.dev/docs/get-started/install/macos
# 下载 Flutter SDK，解压到 ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
flutter doctor
```

### 2. 构建 Android APK
```bash
cd ReminderFlutter
flutter pub get
flutter build apk --debug
# APK: build/app/outputs/flutter-apk/app-debug.apk
```

### 3. 构建 iOS（需要 Xcode）
```bash
flutter pub get
open ios/Runner.xcworkspace
# Xcode 中：登录 Apple ID → 选择真机 → 运行
```

---

## 二、云端构建 iOS（无需本地 Mac）

### 方法 1：GitHub Actions（推荐，免费，但需要签名证书）

1. **上传代码到 GitHub**
   ```bash
   # 在 GitHub 创建新仓库，上传 ReminderFlutter 文件夹
   ```

2. **配置 Apple 签名证书**（需要 Apple 开发者账号 ¥688/年）
   - 在 GitHub 仓库设置中添加 Secrets：
     - `APPLE_CERTIFICATE`：证书 base64
     - `APPLE_CERTIFICATE_PASSWORD`：证书密码
     - `APPLE_SIGNING_IDENTITY`：签名身份（如 "Apple Development: 你的名字 (TEAMID)"）
     - `APPLE_PROFILE`： provisioning profile

3. **触发构建**：Push 代码或手动运行 workflow

4. **下载 IPA**：在 Actions 页面下载 artifact

### 方法 2：Codemagic（免费 tier 可用）

1. 注册 https://codemagic.io
2. 连接 GitHub 仓库
3. 选择 Flutter 项目，一键构建
4. 下载 .ipa 或 .apk

### 方法 3：Bitrise（免费 tier 可用）

1. 注册 https://bitrise.io
2. 连接 GitHub 仓库
3. 添加 Flutter 项目
4. 构建后下载 IPA

---

## 三、无需签名的测试方案

### 模拟器版本（仅供调试，无法安装到真机）

```bash
flutter build ios --simulator --no-codesign
# 产物：build/ios/iphonesimulator/Runner.app
# 可通过 xcrun simctl install 安装到模拟器
```

---

## 四、项目结构

```
ReminderFlutter/
├── lib/main.dart              # Flutter 主程序
├── android/                   # Android 原生配置
├── ios/                      # iOS 原生配置
├── .github/workflows/        # GitHub Actions 自动构建
└── pubspec.yaml              # 依赖配置
```

---

## 五、权限说明

| 权限 | 用途 |
|------|------|
| 通知 | 锁屏弹出提醒 |
| 精确闹钟（Android） | 精确计时 1~4 分钟 |
| 后台运行（Android） | 锁屏后持续工作 |
| 后台刷新（iOS） | 后台触发提醒 |

---

## 六、常见问题

### Q: iOS 通知不弹出？
A: 检查手机设置 → 通知 → 随机提醒 → 允许通知，并开启"时效性通知"

### Q: Android 后台被杀掉？
A: 在电池设置中把本应用设为"不优化"，允许后台运行

### Q: 想安装到朋友/家人的 iPhone？
A: 需要 Apple 开发者账号创建 TestFlight，或让他们登录你的 Apple ID 在你的 Mac 上签名
