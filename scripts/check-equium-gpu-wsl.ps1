param(
  [string]$Backend = ""
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

if (-not $Backend) { $Backend = $env:EQUIUM_GPU_BACKEND }
$projectDirExpanded = Expand-WslPath (Get-ProjectDir)

function Invoke-GpuMiner([string[]]$MinerArgs) {
  $command = @()
  if ($Backend) {
    $command += @("env", "EQUIUM_BACKEND=$Backend")
  }
  $command += @("./target/release/equium-gpu-miner")
  $command += $MinerArgs
  $wslArgs = @("--cd", $projectDirExpanded, "--") + $command
  & wsl.exe @wslArgs
}

Write-Host "Equium WSL GPU miner"
Write-Host "Project: $(Get-ProjectDir)"
if ($Backend) { Write-Host "Backend: $Backend" }
Write-Host ""

Invoke-GpuMiner @("--version")
Write-Host ""
Invoke-GpuMiner @("verify-cpu")
Write-Host ""
Invoke-GpuMiner @("verify")

