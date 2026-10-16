# Stub new lib (ptr-u7b-2 fixture): ls, cd and sort are benign.
command_is_provably_benign() {
  case "$1" in
    "ls"|"ls "*|"cd "*|"sort "*) return 0 ;;
  esac
  return 1
}
