def wsl-path-fix [] {
  let wsl_exe = '/mnt/c/Windows/System32/wsl.exe'
  if not ('/proc/version' | path exists) {
    return
  }
  let version = (open /proc/version | str downcase)
  if not ($version | str contains 'microsoft') {
    return
  }
  if not ($wsl_exe | path exists) {
    return
  }
  let full = (^$wsl_exe echo '$PATH' | str trim | str trim --char '\r')
  if ($full | is-empty) {
    return
  }
  $env.PATH = ($full | split row ':')
}
