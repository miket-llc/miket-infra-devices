#!/usr/bin/env python3
"""
Ollama System Tray Controller
KDE Plasma system tray application for managing Ollama LLM service.
Uses pystray for better Wayland/KDE compatibility.
"""

import subprocess
import signal
import sys
import threading
import time
import math
from pathlib import Path

import pystray
from PIL import Image, ImageDraw

# Dark icon has proper transparency - we'll make it white for dark themes
ICON_PATH = "/usr/share/icons/hicolor/256x256/apps/ollama.png"
CHECK_INTERVAL = 3  # seconds

# Badge colors
COLOR_RUNNING = (46, 204, 113)     # Green - online
COLOR_STOPPED = (231, 76, 60)      # Red - offline  
COLOR_TRANSITION = (241, 196, 15)  # Yellow - starting/stopping
COLOR_ERROR = (155, 89, 182)       # Purple - error

# States
STATE_RUNNING = "running"
STATE_STOPPED = "stopped"
STATE_STARTING = "starting"
STATE_STOPPING = "stopping"
STATE_ERROR = "error"


def get_ollama_state():
    """
    Get actual ollama service state. Returns (state, error_msg).
    Never lies about the state.
    """
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "ollama"],
            capture_output=True, text=True, timeout=5
        )
        status = result.stdout.strip()
        if status == "active":
            return STATE_RUNNING, None
        elif status in ("inactive", "dead"):
            return STATE_STOPPED, None
        elif status == "activating":
            return STATE_STARTING, None
        elif status == "deactivating":
            return STATE_STOPPING, None
        elif status == "failed":
            # Get failure reason
            try:
                detail = subprocess.run(
                    ["systemctl", "status", "ollama", "--no-pager", "-l"],
                    capture_output=True, text=True, timeout=5
                )
                return STATE_ERROR, f"Service failed:\n{detail.stdout[-500:]}"
            except Exception as e:
                return STATE_ERROR, f"Service failed (couldn't get details: {e})"
        else:
            return STATE_ERROR, f"Unknown service state: {status}"
    except subprocess.TimeoutExpired:
        return STATE_ERROR, "Timeout checking service status"
    except Exception as e:
        return STATE_ERROR, f"Error checking status: {e}"


def run_systemctl(action):
    """
    Run systemctl action. Returns (success, error_msg).
    """
    try:
        result = subprocess.run(
            ["sudo", "systemctl", action, "ollama"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return False, f"systemctl {action} failed: {result.stderr or result.stdout}"
        return True, None
    except subprocess.TimeoutExpired:
        return False, f"Timeout running systemctl {action}"
    except Exception as e:
        return False, f"Error running systemctl {action}: {e}"


def get_models():
    """Get list of installed models."""
    try:
        result = subprocess.run(
            ["ollama", "list"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')[1:]
            return [line.split()[0] for line in lines if line.strip()]
    except Exception:
        pass
    return []


def load_base_icon():
    """
    Load the base llama icon and convert to white for dark themes.
    """
    if Path(ICON_PATH).exists():
        img = Image.open(ICON_PATH).convert("RGBA")
        r, g, b, a = img.split()
        white = Image.new("L", img.size, 255)
        return Image.merge("RGBA", (white, white, white, a))
    
    # Fallback
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([16, 8, 48, 40], outline=(255, 255, 255, 255), width=3)
    draw.ellipse([20, 44, 44, 60], outline=(255, 255, 255, 255), width=3)
    return img


def create_icon_with_badge(base_img, state, anim_frame=0):
    """
    Create icon with status badge overlay.
    """
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    
    badge_size = int(img.width * 0.45)
    x1 = img.width - badge_size
    y1 = img.height - badge_size
    x2 = x1 + badge_size
    y2 = y1 + badge_size
    
    # Pick color
    if state == STATE_RUNNING:
        color = COLOR_RUNNING
    elif state in (STATE_STARTING, STATE_STOPPING):
        color = COLOR_TRANSITION
    elif state == STATE_ERROR:
        color = COLOR_ERROR
    else:
        color = COLOR_STOPPED
    
    # Dark outline
    outline = 4
    draw.ellipse(
        [x1 - outline, y1 - outline, x2 + outline, y2 + outline],
        fill=(20, 20, 20, 255)
    )
    
    # Main badge
    draw.ellipse([x1, y1, x2, y2], fill=(*color, 255))
    
    if state == STATE_STOPPED:
        # Slash through circle
        margin = badge_size // 5
        stroke = max(4, badge_size // 10)
        draw.line(
            [x1 + margin, y1 + margin, x2 - margin, y2 - margin],
            fill=(255, 255, 255, 255),
            width=stroke
        )
    elif state in (STATE_STARTING, STATE_STOPPING):
        # Animated rotating dots
        cx = (x1 + x2) // 2
        cy = (y1 + y2) // 2
        radius = badge_size // 4
        dot_size = max(5, badge_size // 10)
        
        for i in range(3):
            angle = (anim_frame * 45 + i * 120) * math.pi / 180
            dx = int(radius * math.cos(angle))
            dy = int(radius * math.sin(angle))
            alpha = 255 if i == 0 else 150
            draw.ellipse(
                [cx + dx - dot_size//2, cy + dy - dot_size//2,
                 cx + dx + dot_size//2, cy + dy + dot_size//2],
                fill=(255, 255, 255, alpha)
            )
    elif state == STATE_ERROR:
        # X mark
        margin = badge_size // 4
        stroke = max(4, badge_size // 10)
        draw.line(
            [x1 + margin, y1 + margin, x2 - margin, y2 - margin],
            fill=(255, 255, 255, 255), width=stroke
        )
        draw.line(
            [x2 - margin, y1 + margin, x1 + margin, y2 - margin],
            fill=(255, 255, 255, 255), width=stroke
        )
    
    return img


class OllamaTray:
    def __init__(self):
        self.app_running = True
        self.current_state = None
        self.last_error = None
        self.anim_frame = 0
        self.anim_timer = None
        self.lock = threading.Lock()
        
        self.base_icon = load_base_icon()
        
        # Pre-generate static icons
        self.static_icons = {
            STATE_RUNNING: create_icon_with_badge(self.base_icon, STATE_RUNNING),
            STATE_STOPPED: create_icon_with_badge(self.base_icon, STATE_STOPPED),
            STATE_ERROR: create_icon_with_badge(self.base_icon, STATE_ERROR),
        }
        
        self.icon = pystray.Icon(
            "ollama-tray",
            self.static_icons[STATE_STOPPED],
            "Ollama",
            menu=self._create_menu()
        )
    
    def _create_menu(self):
        return pystray.Menu(
            pystray.MenuItem(
                lambda text: self._status_text(),
                None,
                enabled=False
            ),
            pystray.MenuItem(
                lambda text: self._models_text(),
                None,
                enabled=False
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                lambda text: "Stop Ollama" if self.current_state == STATE_RUNNING else "Start Ollama",
                self._toggle_ollama,
                enabled=lambda item: self.current_state in (STATE_RUNNING, STATE_STOPPED)
            ),
            pystray.MenuItem("Restart Ollama", self._restart_ollama,
                enabled=lambda item: self.current_state == STATE_RUNNING),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                lambda text: "Show Last Error" if self.last_error else "(No errors)",
                self._show_error,
                enabled=lambda item: self.last_error is not None
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit Tray", self._quit)
        )
    
    def _status_text(self):
        state = self.current_state
        if state == STATE_RUNNING:
            return "● Ollama: Running"
        elif state == STATE_STARTING:
            return "◐ Ollama: Starting..."
        elif state == STATE_STOPPING:
            return "◐ Ollama: Stopping..."
        elif state == STATE_ERROR:
            return "✕ Ollama: Error"
        return "○ Ollama: Stopped"
    
    def _models_text(self):
        if self.current_state == STATE_RUNNING:
            models = get_models()
            if models:
                return f"Models: {', '.join(models[:3])}" + ("..." if len(models) > 3 else "")
            return "Models: (none)"
        return "Models: (offline)"
    
    def _stop_animation(self):
        """Stop any running animation."""
        if self.anim_timer:
            self.anim_timer.cancel()
            self.anim_timer = None
    
    def _start_animation(self, state):
        """Start animation for transitioning states."""
        self._stop_animation()
        self.anim_frame = 0
        self._animate_tick(state)
    
    def _animate_tick(self, state):
        """Single animation frame."""
        if self.current_state not in (STATE_STARTING, STATE_STOPPING):
            return  # State changed, stop animating
        
        self.anim_frame = (self.anim_frame + 1) % 8
        self.icon.icon = create_icon_with_badge(self.base_icon, state, self.anim_frame)
        
        self.anim_timer = threading.Timer(0.15, self._animate_tick, args=[state])
        self.anim_timer.daemon = True
        self.anim_timer.start()
    
    def _set_state(self, new_state, error_msg=None):
        """Update state and icon. Thread-safe."""
        with self.lock:
            old_state = self.current_state
            self.current_state = new_state
            
            if error_msg:
                self.last_error = error_msg
            
            # Stop animation if we're no longer transitioning
            if new_state not in (STATE_STARTING, STATE_STOPPING):
                self._stop_animation()
                self.icon.icon = self.static_icons.get(new_state, self.static_icons[STATE_ERROR])
            elif old_state not in (STATE_STARTING, STATE_STOPPING):
                # Just started transitioning, begin animation
                self._start_animation(new_state)
            
            # Update title
            titles = {
                STATE_RUNNING: "Ollama - Running",
                STATE_STOPPED: "Ollama - Stopped",
                STATE_STARTING: "Ollama - Starting...",
                STATE_STOPPING: "Ollama - Stopping...",
                STATE_ERROR: "Ollama - Error",
            }
            self.icon.title = titles.get(new_state, "Ollama")
            self.icon.update_menu()
    
    def _refresh_state(self):
        """Check actual state and update icon."""
        state, error = get_ollama_state()
        self._set_state(state, error)
    
    def _toggle_ollama(self, icon, item):
        if self.current_state == STATE_RUNNING:
            self._set_state(STATE_STOPPING)
            icon.notify("Stopping Ollama...", "Ollama")
            
            def do_stop():
                success, error = run_systemctl("stop")
                if not success:
                    self._set_state(STATE_ERROR, error)
                    icon.notify(f"Failed to stop: {error[:50]}", "Ollama")
                else:
                    # Poll until stopped
                    for _ in range(10):
                        time.sleep(0.5)
                        state, err = get_ollama_state()
                        if state == STATE_STOPPED:
                            self._set_state(STATE_STOPPED)
                            return
                    self._refresh_state()
            
            threading.Thread(target=do_stop, daemon=True).start()
        
        elif self.current_state == STATE_STOPPED:
            self._set_state(STATE_STARTING)
            icon.notify("Starting Ollama...", "Ollama")
            
            def do_start():
                success, error = run_systemctl("start")
                if not success:
                    self._set_state(STATE_ERROR, error)
                    icon.notify(f"Failed to start: {error[:50]}", "Ollama")
                else:
                    # Poll until running
                    for _ in range(20):
                        time.sleep(0.5)
                        state, err = get_ollama_state()
                        if state == STATE_RUNNING:
                            self._set_state(STATE_RUNNING)
                            return
                        elif state == STATE_ERROR:
                            self._set_state(STATE_ERROR, err)
                            return
                    self._refresh_state()
            
            threading.Thread(target=do_start, daemon=True).start()
    
    def _restart_ollama(self, icon, item):
        self._set_state(STATE_STARTING)
        icon.notify("Restarting Ollama...", "Ollama")
        
        def do_restart():
            success, error = run_systemctl("restart")
            if not success:
                self._set_state(STATE_ERROR, error)
                icon.notify(f"Failed to restart: {error[:50]}", "Ollama")
            else:
                for _ in range(20):
                    time.sleep(0.5)
                    state, err = get_ollama_state()
                    if state == STATE_RUNNING:
                        self._set_state(STATE_RUNNING)
                        return
                    elif state == STATE_ERROR:
                        self._set_state(STATE_ERROR, err)
                        return
                self._refresh_state()
        
        threading.Thread(target=do_restart, daemon=True).start()
    
    def _show_error(self, icon, item):
        if self.last_error:
            icon.notify(self.last_error[:200], "Ollama Error")
    
    def _quit(self, icon, item):
        self.app_running = False
        self._stop_animation()
        icon.stop()
    
    def _monitor_loop(self):
        """Background thread to monitor ollama status."""
        while self.app_running:
            # Don't override transitioning states from monitor
            if self.current_state not in (STATE_STARTING, STATE_STOPPING):
                self._refresh_state()
            time.sleep(CHECK_INTERVAL)
    
    def run(self):
        # Initial state check
        self._refresh_state()
        
        # Start monitoring thread
        monitor = threading.Thread(target=self._monitor_loop, daemon=True)
        monitor.start()
        
        self.icon.run()


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    
    tray = OllamaTray()
    tray.run()


if __name__ == "__main__":
    main()
