# Codex Pet

A small native macOS floating desktop pet that watches Codex Desktop session JSONL files and calls attention when Codex needs you.

The app follows a shimeji-style desktop mascot model: idle animation, walking while Codex works, shaking when Codex needs attention, and hopping when a turn finishes.

Pets:

- Shijima Default, using `DefaultMascot` frames from `pixelomer/Shijima-Qt`
- Doraemon, from `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Patamon, from `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Pikachu, from `Shreyas-Sonawane/Shiemji_DESKTOP_PETS`
- Zhizhiji, from `YuZhu412/zhizhiji-shimeji`
- Mochi
- Capsule

Additional shimeji mascot packs can be added under:

```text
~/.codex/pets/codex-pet/mascots
```

Each pack should be a folder such as `MyCharacter.mascot` with:

```text
MyCharacter.mascot/actions.xml
MyCharacter.mascot/behaviors.xml
MyCharacter.mascot/img/shime1.png
```

Folders with this structure appear automatically under right click -> Choose Pet.

Shijima-Qt is included under `vendor/Shijima-Qt` with its original GPL-3.0 license. Keep that directory and license file if you copy or redistribute this pet.

## What it watches

- `task_started`: switches to Working.
- `task_complete`: switches to Done and sends a macOS notification.
- approval / permission / confirmation events: switches to Needs You and plays a sound.
- errors or aborted turns: switches to Check Codex.

This machine currently runs the active thread with `approval_policy=never`, so real approval prompts may not appear in this session. The detection hooks are still present for sessions that emit approval or confirmation events.

## Run

```bash
open ~/.codex/pets/codex-pet/CodexPet.app
```

The app bundle runs the native AppKit binary:

```bash
~/.codex/pets/codex-pet/codex-pet-native
```

## Install as a login item

```bash
bash ~/.codex/pets/codex-pet/install_launch_agent.sh
```

Uninstall:

```bash
bash ~/.codex/pets/codex-pet/uninstall_launch_agent.sh
```

## Controls

- Drag the window to move it.
- Double click to activate Codex.
- Right click for Open Codex, Test Alert, Choose Pet, Open Mascots Folder, and Quit.
- Choose Pet persists across restarts.
