---
name: help
description: Displays help information and usage instructions for the clipboard plugin.
---

# Instructions
If the user asks for help or usage instructions for the clipboard plugin, display the following help document directly to the screen/user. 

---
🌌 Antigravity Clipboard Bridge

Seamlessly copy text, code blocks, or command outputs from remote environments,
SSH sessions, WSL, and Docker sandboxes to your local host clipboard.

🚀 Quick Start
*   Copy Text: Use '/clipboard:copy <text>' to copy any text to your local clipboard.
*   Show Help: Use '/clipboard:help' to view this help guide.

⚡ Features & Platform Support
*   Supported OS/Shells: macOS, Windows (WSL & PowerShell), Linux
*   Protocols: Low-latency secure OSC 52 escape sequences
*   Transports: SSH sessions, Docker Containers, and local sessions

⚠️ Running inside a Docker Sandbox / Restricted Container?
Since sandboxes cannot directly access the host clipboard, you must start a listener
on your host terminal to bridge the connection:

Option A: Raw Stream (Recommended)
    tail -F .clipboard_bypass > $(tty)

Option B: Named Pipe (Lowest Latency)
    mkfifo .clipboard_pipe
    cat .clipboard_pipe > $(tty)

🛠️ Troubleshooting & Setup Tips
*   Security & Policy Restrictions: If command execution (run_command) is restricted by
    policy, clipboard synchronization will not function. Ensure you are running in
    interactive/authorized mode.
*   Write-Only Transport: The OSC 52 bridge is strictly write-only. It is impossible
    to read or retrieve your clipboard's contents through this bridge.
*   VS Code: Ensure the setting 'terminal.integrated.allowOsc52' is enabled in your settings.
*   SSH: Best results are obtained when an active SSH_TTY is present in your remote session.
*   Browsers: Some browser-based terminals block clipboard writes for security; try a native
    terminal client if copy fails.
