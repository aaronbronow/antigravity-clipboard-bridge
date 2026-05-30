---
name: copy
description: Copies text to the clipboard. Supports setting the user's clipboard from agent CLI on Mac, WSL, Powershell, and over SSH. Optional file bypass mode for Docker sandboxes.
---

# Instructions

When the user asks to copy text, code blocks, or outputs to the clipboard, follow these steps.

### Step 1: Execute Consolidated Helper Script (Primary Method)
To minimize sandbox prompt overhead (avoiding multiple individual permission requests for OS/shell probes and file writes) and prevent escaping bugs, your **primary** and preferred action is to execute the centralized helper script.

#### 1. Execute via Stdin (Recommended for Escape Safety)
To prevent shell-parsing errors or escaping bugs with double quotes (`"`), single quotes (`'`), or backticks (`` ` ``), always stream the text to copy into the script's standard input (stdin), and capture stderr to read the transport status line:

```bash
# Staged plugin path (active)
printf "%s" "YOUR_TEXT_HERE" | ~/.gemini/config/plugins/clipboard/skills/copy/copy_to_clipboard.sh

# Legacy/alternate plugin path
printf "%s" "YOUR_TEXT_HERE" | ~/.gemini/antigravity-cli/plugins/clipboard/skills/copy/copy_to_clipboard.sh

# Cwd/development path
printf "%s" "YOUR_TEXT_HERE" | ./skills/copy/copy_to_clipboard.sh
```

On success, the script writes exactly one line to stderr in the form `Copied via <transport>`, for example:
- `Copied via PowerShell (WSL → Windows)`
- `Copied via clip.exe (WSL)`
- `Copied via pbcopy (macOS)`
- `Copied via wl-copy (Wayland)`
- `Copied via xclip (X11)`
- `Copied via xsel (X11)`
- `Copied via SSH TTY (OSC 52)`
- `Copied via sandbox bypass file (.clipboard_bypass)`
- `Copied via direct TTY (OSC 52)`
- `Copied via stdout (OSC 52)`

Use this stderr line — not assumptions about the environment — when reporting the transport in Step 3.

**Sandbox/Docker Note**: This consolidated helper script natively handles restricted sandboxes and Docker containers by automatically routing copy sequences to the correct bypass channels (e.g., `.clipboard_bypass`). Always attempt to run this script as your first step, regardless of the active shell, SSH, or sandbox status.

> [!IMPORTANT]
> **Windows Host & Sandbox Bypass**: When executing platform-native clipboard commands or unified helper scripts on Windows hosts, **always request unsandboxed command execution** (e.g., specifying `BypassSandbox: true` in your command tool configuration, or requesting `unsandboxed` host execution). Failing to bypass the sandbox will cause the clipboard operation to succeed silently *inside* the containerized environment without propagating to the user's host clipboard.

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
If the current shell is PowerShell, **always request unsandboxed command execution** (e.g. setting `BypassSandbox: true` or requesting `unsandboxed` host execution) and execute the direct, native copy command. Once host access is approved, this single-line command is extremely stable and reliable:
```powershell
Set-Clipboard -Value "YOUR_TEXT_HERE"
```

###### Troubleshooting PowerShell Failures:
If the direct execution fails, identify the specific exception and remediate as follows:

- **Drive Mismatch / Container Isolation (`DriveNotFoundException`)**:
  If the command fails with *"Cannot find drive. A drive with the name 'Microsoft.PowerShell.Core\FileSystem' does not exist"*, this indicates the command was executed inside an isolated container sandbox that has lost its filesystem provider.
  - **Remediation**: Re-execute the `Set-Clipboard` command on the host by explicitly enabling sandbox bypass/unsandboxed execution.

- **Clipboard Lock / Threading Issue (`ExternalException`) (Fallback Only)**:
  If `Set-Clipboard` is executed with sandbox bypass but fails with *"Requested Clipboard operation did not succeed"*, a temporary clipboard lock is being held by another host process or there is an active threading issue.
  - **Remediation**: Run a robust retry loop as a secondary fallback to wait out temporary locks:
    ```powershell
    for ($i=1; $i -le 5; $i++) {
        try {
            Set-Clipboard -Value "YOUR_TEXT_HERE" -ErrorAction Stop
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
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
Notify the user that the text has been successfully copied to their clipboard, indicating the exact copy method reported by the helper script's `Copied via <transport>` stderr output.

