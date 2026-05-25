---
name: copy
description: Copies text to the clipboard. Supports setting the user's clipboard from agent CLI on Mac, WSL, Powershell, and over SSH. Optional file bypass mode for Docker sandboxes.
---

# Instructions

When the user asks to copy text, code blocks, or outputs to the clipboard, follow these steps.

### Step 1: Execute Consolidated Helper Script (Primary Method)
To minimize sandbox prompt overhead (avoiding multiple individual permission requests for OS/shell probes and file writes), your **primary** and preferred action is to execute the centralized, pre-configured helper script in a single `run_command` call.

Execute the helper script at its absolute staged or legacy path:
```bash
# Staged plugin path (active)
~/.gemini/config/plugins/clipboard/skills/copy/copy_to_clipboard.sh "YOUR_TEXT_HERE"

# Legacy/alternate plugin path
~/.gemini/antigravity-cli/plugins/clipboard/skills/copy/copy_to_clipboard.sh "YOUR_TEXT_HERE"

# Cwd/development path (if running in the plugin/workspace directory itself)
./skills/copy/copy_to_clipboard.sh "YOUR_TEXT_HERE"
```

**Sandbox/Docker Note**: This consolidated helper script natively handles restricted sandboxes and Docker containers by automatically routing copy sequences to the correct bypass channels (e.g., `.clipboard_bypass`). Always attempt to run this script as your first step, regardless of the active shell, SSH, or sandbox status.

**Escaping**: Properly escape any double quotes (`"`) or backticks (`` ` ``) in the text argument to ensure shell execution parses the argument correctly.

---

### Step 2: Platform-Native Fallbacks (Use ONLY if the script is missing or fails)
In the rare event that executing the script fails, is blocked by system policies, or is unavailable, you may fall back to direct, individual environment probes and native commands.

#### A. Detect Active Platform & Shell
Analyze the `<USER_INFORMATION>` metadata or run quick shell probes to determine:
- The OS (Windows, macOS, or Linux)
- The shell environment (PowerShell, CMD, bash, zsh, etc.)
- Whether you are running in a restricted sandbox/Docker container or remote SSH session.

#### B. Choose and Execute the Best Copy Method
Invoke the `run_command` tool to execute the appropriate platform-native copy utility:

##### 1. Windows (PowerShell Shell)
If the current shell is PowerShell, run:
```powershell
Set-Clipboard -Value "YOUR_TEXT_HERE"
```

##### 2. Windows (CMD or WSL)
If running under a standard Windows CMD shell or inside a WSL environment with host access:
```bash
echo -n "YOUR_TEXT_HERE" | clip.exe
```

##### 3. macOS (zsh/bash)
If running on macOS:
```bash
echo -n "YOUR_TEXT_HERE" | pbcopy
```

##### 4. Linux (with Display Server)
If running on desktop Linux with a display server, select the first available:
- **Wayland**: `echo -n "YOUR_TEXT_HERE" | wl-copy`
- **X11 (xclip)**: `echo -n "YOUR_TEXT_HERE" | xclip -selection clipboard`
- **X11 (xsel)**: `echo -n "YOUR_TEXT_HERE" | xsel --clipboard --input`

##### 5. Remote SSH Session
If running on a remote server with an active `$SSH_TTY` terminal:
```bash
printf "\033]52;c;$(echo -n "YOUR_TEXT_HERE" | base64 | tr -d '\r\n')\007" > "$SSH_TTY"
```

##### 6. Restricted Sandboxes (Docker/Containers)
If running inside a Docker container or sandbox without direct host device access, write the OSC 52 sequence to the shared bypass channels in the workspace directory:
```bash
printf "\033]52;c;$(echo -n "YOUR_TEXT_HERE" | base64 | tr -d '\r\n')\007" > .clipboard_bypass
```
*(Optionally, write to `.clipboard_pipe` if the named pipe exists)*

---

### Step 3: Verify and Confirm
Notify the user that the text has been successfully copied to their clipboard, indicating the copy method utilized (e.g. via the unified helper script or specific fallback transport).
