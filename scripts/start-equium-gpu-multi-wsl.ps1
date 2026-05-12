param(
  [int]$Lanes = -1,
  [string]$RpcUrl = "",
  [string]$Keypair = "",
  [int]$ThreadsPerLane = -1,
  [int]$MaxBlocks = -1,
  [string]$Backend = "",
  [switch]$Hybrid,
  [switch]$NoMonitor,
  [switch]$DryRun
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

if ($Lanes -lt 1) {
  $Lanes = if ($env:EQUIUM_GPU_MULTI_LANES) { [int]$env:EQUIUM_GPU_MULTI_LANES } else { 16 }
}
if (-not $RpcUrl) { $RpcUrl = $env:EQUIUM_RPC_URL }
if (-not $Keypair) { $Keypair = $env:EQUIUM_KEYPAIR }
if (-not $Backend) { $Backend = $env:EQUIUM_GPU_BACKEND }
if ($ThreadsPerLane -lt 0) {
  $ThreadsPerLane = if ($env:EQUIUM_GPU_THREADS_PER_LANE) { [int]$env:EQUIUM_GPU_THREADS_PER_LANE } else { 1 }
}
if ($MaxBlocks -lt 0) {
  $MaxBlocks = if ($env:EQUIUM_MAX_BLOCKS) { [int]$env:EQUIUM_MAX_BLOCKS } else { 0 }
}

if (-not $RpcUrl) { $RpcUrl = "https://api.mainnet-beta.solana.com" }
if (-not $Keypair) { $Keypair = "~/.config/equium/official-id.json" }
$logDir = if ($env:EQUIUM_GPU_MULTI_LOG_DIR) { $env:EQUIUM_GPU_MULTI_LOG_DIR } else { "~/.config/equium/gpu-multi" }
$useFullGpu = -not $Hybrid.IsPresent

$deriveScript = Join-Path $PSScriptRoot "derive-wallet-address.py"
$keypairHostPath = Convert-WslPathToUnc $Keypair
if (-not (Test-Path -LiteralPath $keypairHostPath)) {
  throw "Could not find miner keypair at $Keypair. Run .\scripts\import-official-wallet.ps1 first."
}
$derivedAddressOutput = & python $deriveScript $keypairHostPath 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Could not read miner keypair. Details: $derivedAddressOutput"
}
$derivedAddress = (($derivedAddressOutput | Select-Object -Last 1) | ConvertFrom-Json).address
if ($env:EQUIUM_EXPECTED_PUBKEY -and $derivedAddress -ne $env:EQUIUM_EXPECTED_PUBKEY) {
  throw "Configured keypair derives $derivedAddress, expected $env:EQUIUM_EXPECTED_PUBKEY. Refusing to start."
}

$projectDirExpanded = Expand-WslPath (Get-ProjectDir)
$logDirExpanded = Expand-WslPath $logDir
$keypairExpanded = Expand-WslPath $Keypair
$mode = if ($useFullGpu) { "full" } else { "hybrid" }

Write-Host "Starting Equium GPU multi-lane mining..."
Write-Host "Lanes: $Lanes"
Write-Host "Mode: $mode"
Write-Host "Backend: $Backend"
Write-Host "Threads per lane: $ThreadsPerLane"
Write-Host "Keypair: $Keypair"
Write-Host "Signer: $derivedAddress"
Write-Host "Log dir: $logDir"
Write-Host "CPU miner: will not be stopped"

$launcher = @'
set -euo pipefail
project_dir="$1"
log_dir="$2"
rpc_url="$3"
keypair="$4"
lanes="$5"
threads="$6"
max_blocks="$7"
backend="$8"
mode="$9"

mkdir -p "$log_dir"
date -u +%FT%TZ > "$log_dir/started-at.txt"
printf '%s\n' "$mode" > "$log_dir/mode.txt"

for i in $(seq 1 "$lanes"); do
  lane="$(printf '%02d' "$i")"
  log="$log_dir/worker-$lane.log"
  pidfile="$log_dir/worker-$lane.pid"
  if [[ -f "$pidfile" ]]; then
    old_pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      echo "lane $lane already running as pid $old_pid"
      continue
    fi
  fi

  args=(env)
  if [[ -n "$backend" ]]; then args+=("EQUIUM_BACKEND=$backend"); fi
  args+=("./target/release/equium-gpu-miner" "mine" "--rpc-url" "$rpc_url" "--keypair" "$keypair" "--threads" "$threads" "--max-blocks" "$max_blocks")
  if [[ "$mode" == "full" ]]; then args+=("--full-gpu"); fi
  ( cd "$project_dir"; nohup nice -n 5 "${args[@]}" > "$log" 2>&1 < /dev/null & echo $! > "$pidfile" )
  echo "started lane $lane pid $(cat "$pidfile")"
  sleep 0.25
done
'@

if ($DryRun) {
  Write-Host "Dry run. No miners started."
  return
}

$launcherB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($launcher))
$cmd = "printf '%s' '$launcherB64' | base64 -d | bash -s -- '$projectDirExpanded' '$logDirExpanded' '$RpcUrl' '$keypairExpanded' '$Lanes' '$ThreadsPerLane' '$MaxBlocks' '$Backend' '$mode'"
wsl.exe -- bash -lc $cmd

if (-not $NoMonitor) {
  Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "monitor-equium-gpu-multi-wsl.ps1")
  )
}

