param(
  [string]$RpcUrl = "",
  [string]$Keypair = "",
  [int]$Threads = -1,
  [int]$MaxBlocks = -1
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

if (-not $RpcUrl) { $RpcUrl = $env:EQUIUM_RPC_URL }
if (-not $Keypair) { $Keypair = $env:EQUIUM_KEYPAIR }
if ($Threads -lt 0) {
  $Threads = if ($env:EQUIUM_THREADS) { [int]$env:EQUIUM_THREADS } else { 0 }
}
if ($MaxBlocks -lt 0) {
  $MaxBlocks = if ($env:EQUIUM_MAX_BLOCKS) { [int]$env:EQUIUM_MAX_BLOCKS } else { 0 }
}

if (-not $RpcUrl) { $RpcUrl = "https://api.mainnet-beta.solana.com" }
if (-not $Keypair) { $Keypair = "~/.config/equium/official-id.json" }

$deriveScript = Join-Path $PSScriptRoot "derive-wallet-address.py"
$keypairHostPath = Convert-WslPathToUnc $Keypair
if (-not (Test-Path -LiteralPath $keypairHostPath)) {
  throw "Could not find miner keypair at $Keypair. Run .\scripts\import-official-wallet.ps1 first."
}

try {
  $derivedAddressOutput = & python $deriveScript $keypairHostPath 2>&1
  $deriveExit = $LASTEXITCODE
} catch {
  $derivedAddressOutput = $_.Exception.Message
  $deriveExit = 1
}
if ($deriveExit -ne 0) {
  throw "Could not read miner keypair. Details: $derivedAddressOutput"
}

$derivedAddressJson = ($derivedAddressOutput | Select-Object -Last 1) | ConvertFrom-Json
$derivedAddress = $derivedAddressJson.address
if ($env:EQUIUM_EXPECTED_PUBKEY -and $derivedAddress -ne $env:EQUIUM_EXPECTED_PUBKEY) {
  throw "Configured keypair derives $derivedAddress, expected $env:EQUIUM_EXPECTED_PUBKEY. Refusing to start."
}

$projectDir = Get-ProjectDir
$projectDirExpanded = Expand-WslPath $projectDir

Write-Host "Starting Equium miner in WSL..."
Write-Host "RPC: $RpcUrl"
Write-Host "Keypair: $Keypair"
Write-Host "Signer: $derivedAddress"
Write-Host "Threads: $Threads"

$wslArgs = @(
  "--cd", $projectDirExpanded,
  "--",
  "./target/release/equium-miner",
  "--rpc-url", $RpcUrl,
  "--keypair", $Keypair,
  "--threads", "$Threads",
  "--max-blocks", "$MaxBlocks"
)

& wsl.exe @wslArgs
