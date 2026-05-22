# Workspace Memory & Learnings

Local development notes for `clipboard`.

## Architecture
- **Production Context**: `skills/help/SKILL.md` and `skills/copy/SKILL.md` define the plugin commands and system-level troubleshooting constraints.
- **Developer Context**: `ANTIGRAVITY.md` and `CONTRIBUTING.md` provide maintenance guidance.
- **Upstream Sync**: Use `make import-upstream` to pull core logic from `agent-bridge-clipboard`.

## Technical Constraints
- **OSC 52**: Write-only. Do not attempt to read the clipboard.
- **Path Resolution**: Use absolute, shell-expandable paths in `SKILL.md` instructions (e.g., `~/.gemini/antigravity-cli/plugins/clipboard/...`) to ensure scripts resolve properly regardless of the current working directory.
- **Environment Isolation**: In sandboxes (Docker), use the `.clipboard_bypass` listener on the host.
