set -l _wsl_ver
if not read -l _wsl_ver < /proc/version
  return 1
end
if not string match -qi '*microsoft*' -- $_wsl_ver
  return 1
end
if not test -x /mnt/c/Windows/System32/wsl.exe
  return 1
end
set -l full (/mnt/c/Windows/System32/wsl.exe echo '$PATH')
if test -z "$full"
  return 1
end
set -gx PATH (string split : -- "$full")
