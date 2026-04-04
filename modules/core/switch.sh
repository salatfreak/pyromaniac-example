# start shell session as other user to work with its services/data
switch() {
  sudo -u "$1" \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$1")/bus \
    sh -c 'cd && exec bash'
}

# add bash completion for non-system users
_switch() {
  users="$(awk -F: '$3 > 1000 { print $1 }' /etc/passwd)"
  COMPREPLY=($(compgen -W "$users" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F _switch switch
