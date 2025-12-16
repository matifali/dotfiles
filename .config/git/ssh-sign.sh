#!/usr/bin/env bash
# Wrapper for ssh-keygen signing that ensures correct SSH agent is used
# Works with 1Password SSH agent (macOS) or forwarded agent (Linux)

# On macOS, explicitly use 1Password agent socket if available
if [[ "$(uname)" == "Darwin" ]] && [[ -S "$HOME/.1password/agent.sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

# Pass all arguments to ssh-keygen
exec /usr/bin/ssh-keygen "$@"
