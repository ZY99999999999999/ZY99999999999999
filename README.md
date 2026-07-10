# Codex Pet / Codex 桌面宠物

Codex Pet is a small native macOS floating desktop pet for Codex / ChatGPT Desktop.
It watches local Codex session activity and changes animation/status when Codex is
working, finished, waiting for you, or needs attention.

Codex Pet 是一个 macOS 原生桌面宠物。它会悬浮在桌面上，监听本机 Codex /
ChatGPT Desktop 的会话状态，并在 Codex 工作中、完成、等待你操作或出错时切换不同状态。

## 中文说明

### 功能

- 桌面悬浮宠物窗口，支持拖动位置。
- 支持右键菜单切换宠物角色。
- 支持的角色包括：
  - Shijima Default
  - Doraemon
  - Patamon
  - Pikachu
  - Zhizhiji
  - Mochi
  - Capsule
- Codex 工作时切换到工作状态。
- Codex 完成任务时切换到完成状态，并发送 macOS 通知。
- Codex 需要用户确认、权限或注意时切换到提醒状态。
- 支持安装为 macOS 登录项，打开 Codex / ChatGPT Desktop 后自动启动桌宠。

### 运行环境

- macOS
- 已安装 ChatGPT Desktop 或 Codex Desktop
- 本仓库里的 `codex-pet-native` 已经是编译好的 macOS 可执行文件

当前 watcher 会识别这些进程路径：

```text
/Applications/Codex.app/Contents/MacOS/Codex
/Applications/ChatGPT.app/Contents/MacOS/ChatGPT
/Applications/ChatGPT.app/Contents/Resources/codex
```

如果以后 ChatGPT / Codex 更新后又改了路径，只需要更新 `codex_pet_watcher.sh`
里的 `CODEX_PROCESS_PATTERNS`。

### 拉取代码

```bash
git clone git@github.com:ZY99999999999999/ZY99999999999999.git
cd ZY99999999999999
```

如果你没有配置 GitHub SSH，也可以用 HTTPS：

```bash
git clone https://github.com/ZY99999999999999/ZY99999999999999.git
cd ZY99999999999999
```

### 第一次启动

直接打开 app：

```bash
open ./CodexPet.app
```

或者直接运行二进制：

```bash
./codex-pet-native
```

如果提示没有执行权限：

```bash
chmod +x ./codex-pet-native
chmod +x ./CodexPet.app/Contents/MacOS/codex-pet
```

如果 macOS 提示无法打开未验证开发者应用，可以先到：

```text
System Settings -> Privacy & Security
```

允许打开该应用。也可以在终端移除隔离属性：

```bash
xattr -dr com.apple.quarantine ./CodexPet.app ./codex-pet-native
```

### 部署为自动启动

建议把代码放到固定位置，比如：

```bash
mkdir -p ~/.codex/pets
cp -R "$(pwd)" ~/.codex/pets/codex-pet
cd ~/.codex/pets/codex-pet
```

安装登录项：

```bash
bash ./install_launch_agent.sh
```

安装后会生成：

```text
~/Library/LaunchAgents/com.didi.codex-pet.plist
```

这个 LaunchAgent 会运行：

```text
~/.codex/pets/codex-pet/codex_pet_watcher.sh
```

watcher 的行为是：

- 检测到 Codex / ChatGPT Desktop 正在运行时，自动启动桌宠。
- 检测到 Codex / ChatGPT Desktop 退出时，自动关闭桌宠。
- 每 5 秒检查一次。

### 验证部署状态

确认 LaunchAgent 是否运行：

```bash
launchctl print "gui/$(id -u)/com.didi.codex-pet"
```

看到类似内容表示登录项正在运行：

```text
state = running
program = /bin/bash
arguments = {
    /bin/bash
    /Users/<you>/.codex/pets/codex-pet/codex_pet_watcher.sh
}
```

确认桌宠进程是否启动：

```bash
pgrep -fl 'codex-pet-native|codex_pet_watcher'
```

正常情况下会看到：

```text
/Users/<you>/.codex/pets/codex-pet/codex-pet-native
/bin/bash /Users/<you>/.codex/pets/codex-pet/codex_pet_watcher.sh
```

确认日志：

```bash
tail -80 /tmp/codex-pet.out.log
tail -80 /tmp/codex-pet.err.log
```

### 部署完成后的状态

部署成功后应该是这个状态：

- 打开 ChatGPT / Codex Desktop 后，桌面上会出现一个透明背景的宠物窗口。
- 右键桌宠，可以看到菜单：
  - Open Codex
  - Test Alert
  - Choose Pet
  - Open Mascots Folder
  - Quit
- 在 `Choose Pet` 里可以选择 Pikachu、Doraemon、Patamon、Zhizhiji 等角色。
- 选择的角色会保存，下次重启桌宠后仍然保持。
- Codex 正在处理任务时，桌宠会进入工作状态。
- Codex 完成任务时，桌宠会进入完成状态，并触发通知。
- Codex 需要你操作时，桌宠会进入提醒状态并播放提示音。
- 退出 ChatGPT / Codex Desktop 后，watcher 会自动关闭桌宠进程。

### 手动关闭

右键桌宠，选择 `Quit`。

或者用命令：

```bash
pkill -f codex-pet-native
```

### 卸载登录项

```bash
bash ~/.codex/pets/codex-pet/uninstall_launch_agent.sh
```

卸载后会移除：

```text
~/Library/LaunchAgents/com.didi.codex-pet.plist
```

如果还想删除代码：

```bash
rm -rf ~/.codex/pets/codex-pet
```

### 更新代码

如果你是从 GitHub clone 到 `~/.codex/pets/codex-pet`：

```bash
cd ~/.codex/pets/codex-pet
git pull
bash ./install_launch_agent.sh
```

如果你更新了 `codex_pet_watcher.sh`，建议重新安装一次登录项：

```bash
bash ./install_launch_agent.sh
```

### 添加新宠物

把新的 shimeji 角色包放到：

```text
~/.codex/pets/codex-pet/mascots
```

目录结构需要类似：

```text
MyCharacter.mascot/actions.xml
MyCharacter.mascot/behaviors.xml
MyCharacter.mascot/img/shime1.png
```

满足这个结构后，角色会自动出现在：

```text
Right click -> Choose Pet
```

### 许可证和素材来源

本项目包含 `vendor/Shijima-Qt`，它使用原项目的 GPL-3.0 license。
复制、修改或分发本项目时，请保留 `vendor/Shijima-Qt` 目录及其中的 license 文件。

角色素材来源：

- Shijima Default: `pixelomer/Shijima-Qt`
- Doraemon: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Patamon: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Pikachu: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Zhizhiji: `YuZhu412/zhizhiji-shimeji`

## English Guide

### Features

- Native macOS floating desktop pet window.
- Draggable transparent desktop window.
- Right-click menu for controls and mascot selection.
- Built-in mascots:
  - Shijima Default
  - Doraemon
  - Patamon
  - Pikachu
  - Zhizhiji
  - Mochi
  - Capsule
- Switches status while Codex is working.
- Sends a macOS notification when Codex finishes a task.
- Highlights when Codex needs confirmation, permission, or attention.
- Can be installed as a macOS LaunchAgent so it starts automatically with
  ChatGPT / Codex Desktop.

### Requirements

- macOS
- ChatGPT Desktop or Codex Desktop installed
- The repository includes a prebuilt macOS binary: `codex-pet-native`

The watcher currently detects these process paths:

```text
/Applications/Codex.app/Contents/MacOS/Codex
/Applications/ChatGPT.app/Contents/MacOS/ChatGPT
/Applications/ChatGPT.app/Contents/Resources/codex
```

If a future ChatGPT / Codex update changes the app path again, update
`CODEX_PROCESS_PATTERNS` in `codex_pet_watcher.sh`.

### Clone

```bash
git clone git@github.com:ZY99999999999999/ZY99999999999999.git
cd ZY99999999999999
```

HTTPS alternative:

```bash
git clone https://github.com/ZY99999999999999/ZY99999999999999.git
cd ZY99999999999999
```

### First Run

Open the app bundle:

```bash
open ./CodexPet.app
```

Or run the binary directly:

```bash
./codex-pet-native
```

If execution permission is missing:

```bash
chmod +x ./codex-pet-native
chmod +x ./CodexPet.app/Contents/MacOS/codex-pet
```

If macOS blocks the app because it is unsigned, allow it from:

```text
System Settings -> Privacy & Security
```

You can also remove quarantine attributes from Terminal:

```bash
xattr -dr com.apple.quarantine ./CodexPet.app ./codex-pet-native
```

### Deploy as a Login Item

Use a stable installation path:

```bash
mkdir -p ~/.codex/pets
cp -R "$(pwd)" ~/.codex/pets/codex-pet
cd ~/.codex/pets/codex-pet
```

Install the LaunchAgent:

```bash
bash ./install_launch_agent.sh
```

This creates:

```text
~/Library/LaunchAgents/com.didi.codex-pet.plist
```

The LaunchAgent runs:

```text
~/.codex/pets/codex-pet/codex_pet_watcher.sh
```

The watcher:

- Starts the pet when ChatGPT / Codex Desktop is running.
- Stops the pet when ChatGPT / Codex Desktop exits.
- Checks every 5 seconds.

### Verify Deployment

Check the LaunchAgent:

```bash
launchctl print "gui/$(id -u)/com.didi.codex-pet"
```

Expected output includes:

```text
state = running
program = /bin/bash
arguments = {
    /bin/bash
    /Users/<you>/.codex/pets/codex-pet/codex_pet_watcher.sh
}
```

Check the pet process:

```bash
pgrep -fl 'codex-pet-native|codex_pet_watcher'
```

Expected output includes:

```text
/Users/<you>/.codex/pets/codex-pet/codex-pet-native
/bin/bash /Users/<you>/.codex/pets/codex-pet/codex_pet_watcher.sh
```

Check logs:

```bash
tail -80 /tmp/codex-pet.out.log
tail -80 /tmp/codex-pet.err.log
```

### Expected State After Deployment

After deployment succeeds:

- Opening ChatGPT / Codex Desktop automatically starts the floating pet.
- Right-clicking the pet shows:
  - Open Codex
  - Test Alert
  - Choose Pet
  - Open Mascots Folder
  - Quit
- `Choose Pet` lets you switch between Pikachu, Doraemon, Patamon, Zhizhiji,
  and other built-in mascots.
- The selected mascot persists across restarts.
- When Codex is working, the pet enters the working state.
- When Codex finishes, the pet enters the done state and sends a notification.
- When Codex needs user action, the pet enters the attention state and plays a
  sound.
- When ChatGPT / Codex Desktop exits, the watcher stops the pet process.

### Stop Manually

Right-click the pet and choose `Quit`.

Or run:

```bash
pkill -f codex-pet-native
```

### Uninstall Login Item

```bash
bash ~/.codex/pets/codex-pet/uninstall_launch_agent.sh
```

This removes:

```text
~/Library/LaunchAgents/com.didi.codex-pet.plist
```

To remove the code as well:

```bash
rm -rf ~/.codex/pets/codex-pet
```

### Update

If the repository is cloned at `~/.codex/pets/codex-pet`:

```bash
cd ~/.codex/pets/codex-pet
git pull
bash ./install_launch_agent.sh
```

If `codex_pet_watcher.sh` changed, reinstall the LaunchAgent:

```bash
bash ./install_launch_agent.sh
```

### Add More Mascots

Place additional shimeji mascot packs under:

```text
~/.codex/pets/codex-pet/mascots
```

Required structure:

```text
MyCharacter.mascot/actions.xml
MyCharacter.mascot/behaviors.xml
MyCharacter.mascot/img/shime1.png
```

Valid packs appear automatically under:

```text
Right click -> Choose Pet
```

### Licenses and Credits

This project includes `vendor/Shijima-Qt`, which keeps its original GPL-3.0
license. Keep the `vendor/Shijima-Qt` directory and its license files if you
copy, modify, or redistribute this pet.

Mascot sources:

- Shijima Default: `pixelomer/Shijima-Qt`
- Doraemon: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Patamon: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Pikachu: `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Zhizhiji: `YuZhu412/zhizhiji-shimeji`
