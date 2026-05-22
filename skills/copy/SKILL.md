---
name: copy
description: Copies text to the clipboard. Supports setting the user's clipboard from agent CLI on Mac, WSL, Powershell, and over SSH. Optional file bypass mode for Docker sandboxes.
---

# Instructions
If the user asks to copy text to the clipboard, use the command below:

```bash
~/.gemini/antigravity-cli/plugins/clipboard/skills/copy/copy.sh "the text to copy"
```

### Usage Steps:
1. **Identify the Content**: Determine the exact text, code block, or command output to be copied.
2. **Execute Command**: Invoke the `run_command` tool to run the command above. 
3. **Escaping**: Properly escape any double quotes (`"`) or backticks (`` ` ``) in the text argument to ensure standard shell execution parses the argument correctly.
