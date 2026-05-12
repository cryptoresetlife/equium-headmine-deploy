param(
  [string]$LogDir = ""
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

if (-not $LogDir) {
  $LogDir = if ($env:EQUIUM_GPU_MULTI_LOG_DIR) { $env:EQUIUM_GPU_MULTI_LOG_DIR } else { "~/.config/equium/gpu-multi" }
}

$stopper = @'
set -euo pipefail
log_dir="${1/#\~/$HOME}"
if [[ ! -d "$log_dir" ]]; then
  echo "No log dir: $log_dir"
  exit 0
fi
for pidfile in "$log_dir"/worker-*.pid; do
  [[ -f "$pidfile" ]] || continue
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "stopped pid $pid"
  fi
done
'@

$stopperB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($stopper))
$cmd = "printf '%s' '$stopperB64' | base64 -d | bash -s -- '$LogDir'"
wsl.exe -- bash -lc $cmd

