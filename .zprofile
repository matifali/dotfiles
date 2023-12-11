# Update $XDG_DATA_DIRS to include $HOME/.local/share if in a desktop environment

if [[ -n $DESKTOP_SESSION ]]; then
    XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"
fi