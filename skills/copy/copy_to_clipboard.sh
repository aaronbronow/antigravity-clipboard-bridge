#!/bin/bash
# Agent Bridge Clipboard copy utility script
# Enable debug mode by creating a file named '.clipboard_debug' in the agent working directory
# or by setting ABC_DEBUG=1 in the environment.
DEBUG=false
if [ -f ".clipboard_debug" ] || [ "$ABC_DEBUG" = "1" ]; then
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

# Detect if we are in a container/sandbox
IS_SANDBOX=false
if [ -f "/.dockerenv" ] || grep -q "docker" /proc/self/cgroup 2>/dev/null; then
    IS_SANDBOX=true
    log_debug "Sandbox/Container detected"
fi

# 0. Handle Input
if [ $# -eq 0 ]; then
    if [ -t 0 ]; then
        # Stdin is a TTY, no arguments provided - nothing to copy
        log_debug "No input provided and stdin is a TTY"
        exit 0
    fi
    input=$(cat)
else
    input="$*"
fi

encoded=$(printf "%s" "$input" | base64 | tr -d '\n')
osc52_sequence=$(printf "\e]52;c;%s\a" "$encoded")

# Wrap for Tmux passthrough if needed
if [ -n "$TMUX" ]; then
    log_debug "TMUX detected, wrapping OSC 52 sequence"
    osc52_sequence=$(printf "\ePtmux;\e%s\e\\" "$osc52_sequence")
elif [ -n "$STY" ]; then
    log_debug "GNU Screen detected, wrapping OSC 52 sequence"
    osc52_sequence=$(printf "\eP%s\e\\" "$osc52_sequence")
fi

# 1. Primary: Platform-Native Tools (WSL/macOS/Linux)
# Only attempt native tools if NOT in a sandbox (usually lack host access)
if [ "$IS_SANDBOX" = false ]; then
    # WSL / Windows
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_debug "Detected WSL/Microsoft environment"
        if command -v clip.exe >/dev/null; then
            log_debug "Found clip.exe, using it"
            printf "%s" "$input" | clip.exe
            exit 0
        elif command -v powershell.exe >/dev/null; then
            log_debug "Found powershell.exe, using it with UTF-8 encoding"
            # Set UTF8 encoding to prevent corruption of non-ASCII characters
            printf "%s" "$input" | powershell.exe -NoProfile -NonInteractive -Command "[Console]::InputEncoding = [System.Text.Encoding]::UTF8; \$input | Set-Clipboard"
            exit 0
        fi
    fi

    # macOS
    if [[ "$OSTYPE" == "darwin"* ]] && command -v pbcopy >/dev/null; then
        log_debug "Detected macOS, using pbcopy"
        printf "%s" "$input" | pbcopy
        exit 0
    fi

    # Linux (Desktop)
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        if command -v wl-copy >/dev/null; then
            log_debug "Detected Wayland, using wl-copy"
            printf "%s" "$input" | wl-copy
            exit 0
        elif command -v xclip >/dev/null; then
            log_debug "Detected X11, using xclip"
            printf "%s" "$input" | xclip -selection clipboard
            exit 0
        elif command -v xsel >/dev/null; then
            log_debug "Detected X11, using xsel"
            printf "%s" "$input" | xsel --clipboard --input
            exit 0
        fi
    fi
fi

# 2. Secondary: Direct SSH TTY bypass (Reliable for remote background/subshells)
if [ -n "$SSH_TTY" ] && [ -w "$SSH_TTY" ]; then
    log_debug "Writing OSC 52 to SSH_TTY: $SSH_TTY"
    printf "%s" "$osc52_sequence" > "$SSH_TTY"
    exit 0
fi

# 3. Bypass Channels (Mandatory for Sandbox, Fallback for Native)
log_debug "Writing to sandbox bypass channels"

# Write to a regular file using atomic move
printf "%s" "$osc52_sequence" > .clipboard_bypass.tmp
mv .clipboard_bypass.tmp .clipboard_bypass
log_debug "Wrote to .clipboard_bypass"

# Write to a FIFO if it exists
if [ -p ".clipboard_pipe" ]; then
    log_debug "Writing to .clipboard_pipe"
    printf "%s" "$osc52_sequence" > .clipboard_pipe &
fi

# 4. Direct TTY write (Secondary fallback)
# In some sandboxes, /dev/tty is writable but isolated. 
if [ -w "/dev/tty" ]; then
    log_debug "Writing OSC 52 to /dev/tty"
    printf "%s" "$osc52_sequence" > /dev/tty
    if [ "$IS_SANDBOX" = false ]; then
        exit 0
    fi
fi

# 5. Last Resort: Stdout
log_debug "Writing OSC 52 to stdout"
printf "%s" "$osc52_sequence"
