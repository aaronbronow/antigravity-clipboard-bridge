#!/bin/bash
# Claude & Antigravity Clipboard Bridge - cross-environment copy utility script
# Version: 1.0.4
VERSION="1.0.4"
#
# Enables seamless copy syncing from local shells, WSL, macOS, Linux, SSH sessions,
# and containerized Docker sandboxes back to the user's host clipboard.
#
# Enable debug mode by creating a file named '.clipboard_debug' in the working directory
# or by setting CLAUDE_CLIPBOARD_DEBUG=1 or ABC_DEBUG=1 in the shell environment.

DEBUG=false
if [ -f ".clipboard_debug" ] || [ "$CLAUDE_CLIPBOARD_DEBUG" = "1" ] || [ "$ABC_DEBUG" = "1" ]; then
    DEBUG=true
    DEBUG_LOG="clipboard_debug.log"
    echo "--- $(date) ---" >> "$DEBUG_LOG"
    echo "Args: $*" >> "$DEBUG_LOG"
fi

log_debug() {
    if [ "$DEBUG" = true ]; then
        echo "$1" >> "$DEBUG_LOG"
    fi
}

# Print a single status line to stderr on successful copy.
# This is always emitted (not just in debug mode) so callers can report
# the exact transport to the user without guessing.
copied_via() {
    echo "Copied via $1" >&2
}

# Detect container sandbox isolation
IS_SANDBOX=false
if [ -f "/.dockerenv" ] || grep -q "docker" /proc/self/cgroup 2>/dev/null; then
    IS_SANDBOX=true
    log_debug "Sandbox/Container environment detected"
fi

# 0. Handle Stdin and Arguments input cleanly
if [ $# -eq 0 ]; then
    if [ -t 0 ]; then
        # Stdin is a TTY and no arguments provided - nothing to copy
        log_debug "No input provided via arguments and stdin is a TTY"
        exit 0
    fi
    input=$(cat)
else
    input="$*"
fi

# Encode string into base64 for reliable terminal sequence parsing
encoded=$(printf "%s" "$input" | base64 | tr -d '\n')
osc52_sequence=$(printf "\e]52;c;%s\a" "$encoded")

# Wrap for multiplexer passthrough if running under Tmux or GNU Screen
if [ -n "$TMUX" ]; then
    log_debug "Tmux detected, wrapping OSC 52 sequence"
    osc52_sequence=$(printf "\ePtmux;\e%s\e\\" "$osc52_sequence")
elif [ -n "$STY" ]; then
    log_debug "GNU Screen detected, wrapping OSC 52 sequence"
    osc52_sequence=$(printf "\eP%s\e\\" "$osc52_sequence")
fi

# 1. Primary: Platform-Native Tools (WSL/macOS/Linux)
# Only attempt native tools if NOT in a sandbox (which lacks direct host access)
if [ "$IS_SANDBOX" = false ]; then
    # WSL / Windows host
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_debug "Detected WSL/Microsoft environment"
        if command -v clip.exe >/dev/null; then
            log_debug "Found clip.exe, attempting copy"
            if printf "%s" "$input" | clip.exe 2>/dev/null; then
                log_debug "clip.exe copy succeeded"
                copied_via "clip.exe (WSL)"
                exit 0
            else
                log_debug "clip.exe copy failed, falling through"
            fi
        elif command -v powershell.exe >/dev/null; then
            log_debug "Found powershell.exe, attempting copy with UTF-8 encoding & retry loop"
            if printf "%s" "$input" | powershell.exe -NoProfile -NonInteractive -Command "[Console]::InputEncoding = [System.Text.Encoding]::UTF8; \$content = [Console]::In.ReadToEnd(); for (\$i=1; \$i -le 5; \$i++) { try { Set-Clipboard -Value \$content -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 100 } }" 2>/dev/null; then
                log_debug "powershell.exe copy succeeded"
                copied_via "PowerShell (WSL → Windows)"
                exit 0
            else
                log_debug "powershell.exe copy failed, falling through"
            fi
        fi
    fi

    # macOS
    if [[ "$OSTYPE" == "darwin"* ]] && command -v pbcopy >/dev/null; then
        log_debug "Detected macOS, attempting pbcopy"
        if printf "%s" "$input" | pbcopy 2>/dev/null; then
            log_debug "pbcopy copy succeeded"
            copied_via "pbcopy (macOS)"
            exit 0
        else
            log_debug "pbcopy copy failed, falling through"
        fi
    fi

    # Linux Desktop
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        if command -v wl-copy >/dev/null; then
            log_debug "Detected Wayland, attempting wl-copy"
            if printf "%s" "$input" | wl-copy 2>/dev/null; then
                log_debug "wl-copy copy succeeded"
                copied_via "wl-copy (Wayland)"
                exit 0
            else
                log_debug "wl-copy copy failed, falling through"
            fi
        elif command -v xclip >/dev/null; then
            log_debug "Detected X11, attempting xclip"
            if printf "%s" "$input" | xclip -selection clipboard 2>/dev/null; then
                log_debug "xclip copy succeeded"
                copied_via "xclip (X11)"
                exit 0
            else
                log_debug "xclip copy failed, falling through"
            fi
        elif command -v xsel >/dev/null; then
            log_debug "Detected X11, attempting xsel"
            if printf "%s" "$input" | xsel --clipboard --input 2>/dev/null; then
                log_debug "xsel copy succeeded"
                copied_via "xsel (X11)"
                exit 0
            else
                log_debug "xsel copy failed, falling through"
            fi
        fi
    fi
fi

# 2. Secondary: Direct SSH TTY bypass (Reliable for background subshells/remote CLI)
if [ -n "$SSH_TTY" ] && [ -w "$SSH_TTY" ]; then
    log_debug "Writing OSC 52 sequence directly to SSH_TTY: $SSH_TTY"
    printf "%s" "$osc52_sequence" > "$SSH_TTY"
    copied_via "SSH TTY (OSC 52)"
    exit 0
fi

# 3. Bypass Channels (Mandatory for Sandbox containers, Fallback for native)
log_debug "Writing to sandbox bypass channels"

# Write to regular file atomically to avoid race conditions
printf "%s" "$osc52_sequence" > .clipboard_bypass.tmp
mv .clipboard_bypass.tmp .clipboard_bypass
log_debug "Wrote to .clipboard_bypass"
copied_via "sandbox bypass file (.clipboard_bypass)"

# Write to active Named Pipe (FIFO) if initialized
if [ -p ".clipboard_pipe" ]; then
    log_debug "Writing to active .clipboard_pipe"
    printf "%s" "$osc52_sequence" > .clipboard_pipe &
fi

# 4. Direct TTY write (Secondary fallback)
if [ -w "/dev/tty" ]; then
    log_debug "Writing OSC 52 directly to /dev/tty"
    printf "%s" "$osc52_sequence" > /dev/tty
    if [ "$IS_SANDBOX" = false ]; then
        copied_via "direct TTY (OSC 52)"
        exit 0
    fi
fi

# 5. Last Resort: Stdout
log_debug "Writing OSC 52 sequence directly to stdout"
copied_via "stdout (OSC 52)"
printf "%s" "$osc52_sequence"
