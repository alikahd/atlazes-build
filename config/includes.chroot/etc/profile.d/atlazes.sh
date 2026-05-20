#!/bin/bash
# =============================================================================
# ATLAZES OS - Shell Profile
# Loaded for all users on login
# =============================================================================

# ─── ATLAZES OS environment ───────────────────────────────────────────────────
export ATLAZES_OS="1.0.0"
export ATLAZES_CODENAME="Horizon"

# ─── Security environment ─────────────────────────────────────────────────────
# Restrict umask (files: 640, dirs: 750)
umask 027

# Disable core dumps
ulimit -c 0

# ─── Privacy environment ──────────────────────────────────────────────────────
# Don't save history for sensitive commands
export HISTIGNORE="*sudo*:*password*:*passwd*:*secret*:*key*:*token*:*gpg*:*ssh*"
export HISTCONTROL="ignoreboth:erasedups"
export HISTSIZE=1000
export HISTFILESIZE=2000

# ─── PATH ─────────────────────────────────────────────────────────────────────
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ─── Aliases ──────────────────────────────────────────────────────────────────
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ATLAZES tools
alias atlazes='atlazes-tools'
alias security-status='atlazes-tools status'
alias privacy-clean='atlazes-tools clean'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Network
alias myip='curl -s https://api.ipify.org && echo'
alias localip='ip route get 1 | awk "{print \$7}" | head -1'

# ─── Welcome message ──────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${TERM}" != "dumb" ]]; then
    # Only show in interactive terminals, not scripts
    :
fi
