# systemctl short hand
source /usr/share/bash-completion/completions/systemctl
alias sc='systemctl --user'
_sc() {
  local -a original=("${COMP_WORDS[@]}")
  COMP_WORDS=(systemctl --user "${original[@]:1}"); let ++COMP_CWORD
  _systemctl
  COMP_WORDS=("${original[@]}"); let --COMP_CWORD
}
complete -F _sc sc

# journalctl short hand
source /usr/share/bash-completion/completions/journalctl
alias jc='journalctl --user'
_jc() {
  local -a original=("${COMP_WORDS[@]}")
  COMP_WORDS=(journalctl --user "${original[@]:1}"); let ++COMP_CWORD
  _journalctl
  COMP_WORDS=("${original[@]}"); let --COMP_CWORD
}
complete -F _jc jc
