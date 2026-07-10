#!/usr/bin/env python3
"""Floating Codex status pet for macOS.

The app watches Codex Desktop JSONL session files under ~/.codex/sessions and
turns recent thread events into a small always-on-top UI plus macOS notices.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import tkinter as tk


APP_NAME = "Codex Pet"
APP_DIR = Path(__file__).resolve().parent
CODEX_HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
DEFAULT_SESSIONS_DIR = CODEX_HOME / "sessions"
PET_IMAGE_PATH = APP_DIR / "assets" / "doll.gif"
POLL_MS = 1000
SESSION_REFRESH_MS = 5000
DONE_HOLD_SECONDS = 40
ALERT_KEYWORDS = (
    "approval",
    "approve",
    "permission",
    "confirm",
    "requires approval",
    "requires confirmation",
    "待审批",
    "审批",
    "确认",
    "允许",
)
ALERT_EVENT_TYPES = {
    "approval_request",
    "approval_requested",
    "permission_request",
    "confirmation_request",
    "confirm_request",
    "user_approval_requested",
    "tool_approval_requested",
}
KEYWORD_IGNORED_EVENT_TYPES = {
    "user_message",
    "agent_message",
    "task_started",
    "task_complete",
    "token_count",
    "patch_apply_end",
    "exec_command_end",
    "web_search_end",
    "mcp_tool_call_end",
    "context_compacted",
}


@dataclass
class PetState:
    mode: str = "idle"
    title: str = "Idle"
    detail: str = "Watching Codex"
    session_path: Path | None = None
    updated_at: float = 0
    last_turn_id: str | None = None


class SessionWatcher:
    def __init__(self, sessions_dir: Path, session_path: Path | None = None) -> None:
        self.sessions_dir = sessions_dir
        self.session_path = session_path
        self.offsets: dict[Path, int] = {}
        self.last_session_refresh = 0.0
        self.state = PetState(updated_at=time.time())
        self._bootstrap()

    def _bootstrap(self) -> None:
        path = self._current_session_path()
        if not path:
            return
        self.session_path = path
        self.state.session_path = path
        self.state = self._state_from_tail(path)
        self.offsets[path] = path.stat().st_size

    def _current_session_path(self) -> Path | None:
        if self.session_path and self.session_path.exists():
            return self.session_path
        pattern = str(self.sessions_dir / "**" / "*.jsonl")
        paths = [Path(p) for p in glob.glob(pattern, recursive=True)]
        if not paths:
            return None
        return max(paths, key=lambda p: p.stat().st_mtime)

    def _refresh_session_path(self) -> None:
        now = time.time()
        if now - self.last_session_refresh < SESSION_REFRESH_MS / 1000:
            return
        self.last_session_refresh = now
        newest = self._current_session_path()
        if newest and newest != self.session_path:
            self.session_path = newest
            self.state.session_path = newest
            self.state = self._state_from_tail(newest)
            self.offsets[newest] = newest.stat().st_size

    def _state_from_tail(self, path: Path, max_lines: int = 300) -> PetState:
        lines = tail_lines(path, max_lines)
        state = PetState(mode="idle", title="Idle", detail="Watching Codex", session_path=path, updated_at=time.time())
        for obj in iter_json_lines(lines):
            state = apply_event(state, obj, notify=False)
        if state.mode == "done" and time.time() - state.updated_at > DONE_HOLD_SECONDS:
            state.mode = "idle"
            state.title = "Idle"
            state.detail = "Watching Codex"
        return state

    def poll(self) -> tuple[PetState, list[PetState]]:
        self._refresh_session_path()
        path = self.session_path
        notices: list[PetState] = []
        if not path or not path.exists():
            self.state = PetState(mode="idle", title="No Session", detail="No Codex session file found", updated_at=time.time())
            return self.state, notices

        offset = self.offsets.get(path, 0)
        size = path.stat().st_size
        if size < offset:
            offset = 0
        if size > offset:
            with path.open("r", encoding="utf-8", errors="replace") as fh:
                fh.seek(offset)
                lines = fh.readlines()
                self.offsets[path] = fh.tell()
            for obj in iter_json_lines(lines):
                before = self.state.mode
                self.state = apply_event(self.state, obj, notify=True)
                self.state.session_path = path
                if self.state.mode in {"alert", "done", "error"} and self.state.mode != before:
                    notices.append(self.state)

        if self.state.mode == "done" and time.time() - self.state.updated_at > DONE_HOLD_SECONDS:
            self.state.mode = "idle"
            self.state.title = "Idle"
            self.state.detail = "Watching Codex"
        return self.state, notices


def tail_lines(path: Path, max_lines: int) -> list[str]:
    try:
        with path.open("rb") as fh:
            fh.seek(0, os.SEEK_END)
            end = fh.tell()
            block_size = 8192
            data = b""
            pos = end
            while pos > 0 and data.count(b"\n") <= max_lines:
                read_size = min(block_size, pos)
                pos -= read_size
                fh.seek(pos)
                data = fh.read(read_size) + data
        return data.decode("utf-8", errors="replace").splitlines()[-max_lines:]
    except OSError:
        return []


def iter_json_lines(lines: Iterable[str]) -> Iterable[dict[str, Any]]:
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            yield obj


def payload_type(obj: dict[str, Any]) -> str | None:
    payload = obj.get("payload")
    if isinstance(payload, dict):
        typ = payload.get("type")
        return typ if isinstance(typ, str) else None
    return None


def payload_text(obj: dict[str, Any]) -> str:
    payload = obj.get("payload")
    if not isinstance(payload, dict):
        return ""
    parts: list[str] = []
    for key in ("message", "last_agent_message", "error", "last_error", "status"):
        value = payload.get(key)
        if isinstance(value, str):
            parts.append(value)
    return "\n".join(parts)


def looks_like_approval_request(obj: dict[str, Any]) -> bool:
    typ = payload_type(obj)
    if typ in ALERT_EVENT_TYPES:
        return True
    payload = obj.get("payload")
    if not isinstance(payload, dict):
        return False
    if any(k in payload for k in ("approval_id", "permission_id", "confirmation_id")):
        return True
    if obj.get("type") != "event_msg":
        return False
    if typ in KEYWORD_IGNORED_EVENT_TYPES or (isinstance(typ, str) and typ.endswith("_end")):
        return False
    text = json.dumps(payload, ensure_ascii=False).lower()
    return any(keyword.lower() in text for keyword in ALERT_KEYWORDS)


def apply_event(state: PetState, obj: dict[str, Any], notify: bool) -> PetState:
    typ = payload_type(obj)
    payload = obj.get("payload") if isinstance(obj.get("payload"), dict) else {}
    now = time.time()

    if obj.get("type") == "turn_context" and isinstance(payload, dict):
        turn_id = payload.get("turn_id")
        if isinstance(turn_id, str):
            state.last_turn_id = turn_id

    if looks_like_approval_request(obj):
        state.mode = "alert"
        state.title = "Needs You"
        state.detail = "Codex is waiting for approval"
        state.updated_at = now
        return state

    if typ == "task_started":
        state.mode = "working"
        state.title = "Working"
        state.detail = "Codex is running"
        state.updated_at = now
        turn_id = payload.get("turn_id") if isinstance(payload, dict) else None
        if isinstance(turn_id, str):
            state.last_turn_id = turn_id
        return state

    if typ == "task_complete":
        state.mode = "done"
        state.title = "Done"
        state.detail = "Codex finished this turn"
        state.updated_at = now
        return state

    if typ in {"error", "turn_aborted"}:
        state.mode = "error"
        state.title = "Check Codex"
        state.detail = short_detail(payload_text(obj), "Codex needs attention")
        state.updated_at = now
        return state

    if obj.get("type") == "response_item":
        ptype = payload.get("type") if isinstance(payload, dict) else None
        if ptype in {"function_call", "custom_tool_call", "web_search_call"} and state.mode != "alert":
            state.mode = "working"
            name = payload.get("name") if isinstance(payload, dict) else None
            state.detail = f"Running {name}" if isinstance(name, str) else "Running a tool"
            state.title = "Working"
            state.updated_at = now

    return state


def short_detail(text: str, fallback: str) -> str:
    text = " ".join(text.split())
    if not text:
        return fallback
    return text[:70] + ("..." if len(text) > 70 else "")


def notify(title: str, message: str, sound: bool = True) -> None:
    safe_title = title.replace('"', '\\"')
    safe_message = message.replace('"', '\\"')
    script = f'display notification "{safe_message}" with title "{safe_title}"'
    subprocess.Popen(["osascript", "-e", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if sound:
        sound_path = "/System/Library/Sounds/Glass.aiff"
        subprocess.Popen(["afplay", sound_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def activate_codex() -> None:
    scripts = [
        'tell application "Codex" to activate',
        'tell application "OpenAI Codex" to activate',
    ]
    for script in scripts:
        result = subprocess.run(["osascript", "-e", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            return


class PetWindow:
    def __init__(self, watcher: SessionWatcher, test_alert: bool = False) -> None:
        self.watcher = watcher
        self.muted = False
        self.drag_x = 0
        self.drag_y = 0
        self.frame = 0
        self.last_mode = ""

        self.root = tk.Tk()
        self.root.title(APP_NAME)
        self.root.geometry("188x292+40+160")
        self.root.resizable(False, False)
        self.root.attributes("-topmost", True)
        self.root.configure(bg="#101114")

        self.pet_image = tk.PhotoImage(file=str(PET_IMAGE_PATH)) if PET_IMAGE_PATH.exists() else None
        self.canvas = tk.Canvas(self.root, width=188, height=292, bg="#101114", highlightthickness=0)
        self.canvas.pack()
        self.canvas.bind("<ButtonPress-1>", self.start_drag)
        self.canvas.bind("<B1-Motion>", self.drag)
        self.canvas.bind("<Double-Button-1>", lambda _event: activate_codex())
        self.canvas.bind("<Button-2>", self.show_menu)
        self.canvas.bind("<Button-3>", self.show_menu)

        self.menu = tk.Menu(self.root, tearoff=0)
        self.menu.add_command(label="Open Codex", command=activate_codex)
        self.menu.add_command(label="Test Alert", command=self.test_alert)
        self.menu.add_command(label="Mute", command=self.toggle_mute)
        self.menu.add_separator()
        self.menu.add_command(label="Quit", command=self.root.destroy)

        if test_alert:
            self.root.after(400, self.test_alert)
        self.root.after(100, self.root.lift)
        self.root.after(120, lambda: self.root.attributes("-topmost", True))
        self.tick()

    def start_drag(self, event: tk.Event) -> None:
        self.drag_x = event.x
        self.drag_y = event.y

    def drag(self, event: tk.Event) -> None:
        x = self.root.winfo_x() + event.x - self.drag_x
        y = self.root.winfo_y() + event.y - self.drag_y
        self.root.geometry(f"+{x}+{y}")

    def show_menu(self, event: tk.Event) -> None:
        self.menu.tk_popup(event.x_root, event.y_root)

    def toggle_mute(self) -> None:
        self.muted = not self.muted
        self.menu.entryconfigure(2, label="Unmute" if self.muted else "Mute")

    def test_alert(self) -> None:
        state = PetState(mode="alert", title="Needs You", detail="Codex is waiting for approval", updated_at=time.time())
        self.draw(state)
        if not self.muted:
            notify(f"{APP_NAME}: Needs You", state.detail)

    def tick(self) -> None:
        state, notices = self.watcher.poll()
        self.frame += 1
        self.draw(state)
        for item in notices:
            if not self.muted:
                notify(f"{APP_NAME}: {item.title}", item.detail, sound=item.mode in {"alert", "error"})
        self.root.after(POLL_MS, self.tick)

    def draw(self, state: PetState) -> None:
        self.canvas.delete("all")
        colors = {
            "idle": ("#475467", "#f2f4f7"),
            "working": ("#276fbf", "#eaf3ff"),
            "done": ("#2fa66a", "#e9f8ef"),
            "alert": ("#e84d2a", "#fff0e8"),
            "error": ("#d93f5c", "#fff0f4"),
        }
        accent, panel = colors.get(state.mode, colors["idle"])
        pulse = 0
        if state.mode in {"working", "alert", "error"}:
            pulse = 3 if self.frame % 2 == 0 else 0

        self.canvas.create_rectangle(0, 0, 188, 292, fill="#101114", outline="#101114")
        self.round_rect(7, 7 + pulse, 181, 255 + pulse, 16, fill="#1c1f25", outline="#2d323b")
        if self.pet_image:
            self.canvas.create_image(94, 128 + pulse, image=self.pet_image)
        else:
            self.round_rect(20, 20, 168, 240, 18, fill="#f6a43a", outline="#ffca75")
            self.canvas.create_text(94, 130, text="Codex Pet", fill="#20242a", font=("Menlo", 14, "bold"))

        self.canvas.create_oval(133, 15 + pulse, 177, 59 + pulse, fill=accent, outline="#ffffff", width=2)
        badge = {"idle": "OK", "working": "...", "done": "✓", "alert": "!", "error": "!"}.get(state.mode, "OK")
        self.canvas.create_text(155, 37 + pulse, text=badge, fill="#ffffff", font=("Menlo", 18, "bold"))

        self.round_rect(11, 258, 177, 288, 15, fill=panel, outline=accent)
        self.canvas.create_text(94, 269, text=state.title, fill="#101828", font=("Menlo", 11, "bold"))
        self.canvas.create_text(94, 282, text=short_detail(state.detail, ""), fill="#475467", font=("Menlo", 8))

    def round_rect(self, x1: int, y1: int, x2: int, y2: int, radius: int, **kwargs: Any) -> None:
        points = [
            x1 + radius, y1, x2 - radius, y1, x2, y1, x2, y1 + radius,
            x2, y2 - radius, x2, y2, x2 - radius, y2, x1 + radius, y2,
            x1, y2, x1, y2 - radius, x1, y1 + radius, x1, y1,
        ]
        self.canvas.create_polygon(points, smooth=True, **kwargs)

    def run(self) -> None:
        self.root.mainloop()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Floating Codex Desktop status pet")
    parser.add_argument("--sessions-dir", type=Path, default=DEFAULT_SESSIONS_DIR)
    parser.add_argument("--session", type=Path, help="Watch one JSONL session file instead of the newest session")
    parser.add_argument("--once", action="store_true", help="Print detected state and exit")
    parser.add_argument("--test-alert", action="store_true", help="Start with a visible alert and notification")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    watcher = SessionWatcher(args.sessions_dir.expanduser(), args.session.expanduser() if args.session else None)
    if args.once:
        state, _notices = watcher.poll()
        print(json.dumps({
            "mode": state.mode,
            "title": state.title,
            "detail": state.detail,
            "session_path": str(state.session_path) if state.session_path else None,
            "last_turn_id": state.last_turn_id,
        }, ensure_ascii=False, indent=2))
        return 0
    PetWindow(watcher, test_alert=args.test_alert).run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
