err() {
  print -P "%F{red}[ERROR]%f $1"
  return 1
}

warn() {
  print -P "%F{yellow}[WARN]%f $1"
}

info() {
  print -P "%F{cyan}[INFO]%f $1"
}
