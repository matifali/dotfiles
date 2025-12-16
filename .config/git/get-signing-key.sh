#!/bin/bash
# Helper script to get SSH signing key from the agent
# Works with 1Password SSH agent (macOS) or forwarded agent (Linux remote)
# This allows commit signing to work in Zed, VS Code, Cursor, and terminal

# On macOS, explicitly use 1Password agent socket if available
# This ensures signing works even when SSH_AUTH_SOCK isn't set (e.g., in Zed)
if [[ "$OSTYPE" == "darwin"* ]] && [[ -S "$HOME/.1password/agent.sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

# Get the first SSH key from the agent
KEY=$(ssh-add -L 2>/dev/null | head -n 1)

if [ -z "$KEY" ] || [[ "$KEY" == *"no identities"* ]]; then
    echo "Error: No SSH keys found in agent. Ensure 1Password agent is running (macOS) or SSH agent is forwarded (Linux)." >&2
    exit 1
fi

# Output in the format git expects
echo "key::$KEY"
