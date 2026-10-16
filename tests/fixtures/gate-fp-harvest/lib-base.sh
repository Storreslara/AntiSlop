# Stub baseline lib (ptr-u7b-2 fixture): only ls is benign.
command_is_provably_benign() {
  case "$1" in
    "ls"|"ls "*) return 0 ;;
  esac
  return 1
}
