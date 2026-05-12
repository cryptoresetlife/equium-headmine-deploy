. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

$rpc = if ($env:EQUIUM_RPC_URL) { $env:EQUIUM_RPC_URL } else { "https://api.mainnet-beta.solana.com" }
$projectDir = Get-ProjectDir
$keypair = if ($env:EQUIUM_KEYPAIR) { $env:EQUIUM_KEYPAIR } else { "~/.config/equium/official-id.json" }
$expectedPubkey = $env:EQUIUM_EXPECTED_PUBKEY

function Invoke-SolanaRpc($method, $params) {
  $body = @{
    jsonrpc = "2.0"
    id = 1
    method = $method
    params = $params
  } | ConvertTo-Json -Depth 10
  Invoke-RestMethod -Uri $rpc -Method Post -Body $body -ContentType "application/json"
}

$program = "ZKGMUfxiRCXFPnqz9zgqAnuqJy15jk7fKbR4o6FuEQM"
$claimedMint = "1MhvZzEe8gQ8Rb9CrT3Dn26Gkn9QRErzLMGkkTwveqm"
$configPda = "CfMckeL8ZmUKGRtjohMmqTo3nuWVGTRm2hkkny3GVkeS"

Write-Host "Equium WSL miner"
$projectDirExpanded = Expand-WslPath $projectDir
wsl.exe --cd $projectDirExpanded -- ./target/release/equium-miner --version
Write-Host ""
Write-Host "Wallet"

$keypairHostPath = Convert-WslPathToUnc $keypair
$deriveScript = Join-Path $PSScriptRoot "derive-wallet-address.py"
$walletInfoOutput = $null
$walletInfoExit = 1
if (Test-Path -LiteralPath $keypairHostPath) {
  try {
    $walletInfoOutput = & python $deriveScript $keypairHostPath 2>&1
    $walletInfoExit = $LASTEXITCODE
  } catch {
    $walletInfoOutput = $_.Exception.Message
    $walletInfoExit = 1
  }
} else {
  $walletInfoOutput = "keypair file does not exist"
}

$walletAddress = $null
$walletOk = $false
$feeOk = $false
if ($walletInfoExit -eq 0) {
  $walletInfo = ($walletInfoOutput | Select-Object -Last 1) | ConvertFrom-Json
  $walletAddress = $walletInfo.address
  Write-Host ("Keypair path: " + $keypair)
  Write-Host ("Signer address: " + $walletAddress)
  $walletOk = $true
  if ($expectedPubkey) {
    $walletOk = $walletAddress -eq $expectedPubkey
    Write-Host ("Expected address match: " + $walletOk)
  }
} else {
  Write-Host ("Keypair path: " + $keypair)
  Write-Host ("Wallet not imported: " + ($walletInfoOutput -join "`n"))
}

Write-Host ""
Write-Host "Source"
wsl.exe --cd $projectDirExpanded -- git rev-parse --short HEAD
wsl.exe --cd $projectDirExpanded -- git status --short
Write-Host ""
Write-Host "Mainnet checks via $rpc"

$programInfo = Invoke-SolanaRpc "getAccountInfo" @($program, @{ encoding = "jsonParsed"; commitment = "confirmed" })
$configInfo = Invoke-SolanaRpc "getAccountInfo" @($configPda, @{ encoding = "base64"; commitment = "confirmed" })
$mintInfo = Invoke-SolanaRpc "getAccountInfo" @($claimedMint, @{ encoding = "jsonParsed"; commitment = "confirmed" })

$programOk = [bool]$programInfo.result.value -and
  $programInfo.result.value.executable -and
  $programInfo.result.value.owner -eq "BPFLoaderUpgradeab1e11111111111111111111111"

$configOk = [bool]$configInfo.result.value -and
  $configInfo.result.value.owner -eq $program -and
  $configInfo.result.value.space -ge 300

$tokenOwners = @(
  "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
  "TokenzQdBNbLqP5VEhdkAS6EPZ1a3UeV5h4uBvf9Ss623VQ5DA"
)
$mintOk = [bool]$mintInfo.result.value -and
  $tokenOwners.Contains($mintInfo.result.value.owner) -and
  $mintInfo.result.value.data.parsed.type -eq "mint"

Write-Host ("Program executable: " + $programOk)
Write-Host ("Config initialized:  " + $configOk)
Write-Host ("Claimed mint is SPL token: " + $mintOk)

if ([bool]$configInfo.result.value -and -not $configOk) {
  Write-Host ("Config address owner/space: " + $configInfo.result.value.owner + " / " + $configInfo.result.value.space)
}
if ([bool]$mintInfo.result.value -and -not $mintOk) {
  Write-Host ("Claimed mint owner/space: " + $mintInfo.result.value.owner + " / " + $mintInfo.result.value.space)
}

if ($walletAddress) {
  $balance = Invoke-SolanaRpc "getBalance" @($walletAddress, @{ commitment = "confirmed" })
  $feeOk = $balance.result.value -gt 0
  Write-Host ("Hot wallet SOL: " + ($balance.result.value / 1000000000))
}

if ($configOk) {
  $bytes = [Convert]::FromBase64String($configInfo.result.value.data[0])
  $offset = 8 + 32 + 32 + 1 + 1 + 8 + 8 + 4 + 4 + 32
  $blockHeight = [BitConverter]::ToUInt64($bytes, $offset)
  $offset += 8 + 32 + 8 + 8 + 32
  $rewardBase = [BitConverter]::ToUInt64($bytes, $offset)
  $offset += 8 + 8 + 8 + 8
  $cumulativeBase = [BitConverter]::ToUInt64($bytes, $offset)
  $offset += 8
  $emptyRounds = [BitConverter]::ToUInt64($bytes, $offset)
  $offset += 8
  $miningOpen = [bool]$bytes[$offset]
  $offset += 1 + 32
  $adminRenounced = [bool]$bytes[$offset]
  Write-Host ("Mining open: " + $miningOpen)
  Write-Host ("Block height: " + $blockHeight)
  Write-Host ("Reward EQM: " + ($rewardBase / 1000000))
  Write-Host ("Cumulative mined EQM: " + ($cumulativeBase / 1000000))
  Write-Host ("Empty rounds: " + $emptyRounds)
  Write-Host ("Admin renounced: " + $adminRenounced)
}

$ready = $programOk -and $configOk -and $mintOk -and $walletOk -and $feeOk
if ($configOk) {
  $ready = $ready -and $miningOpen
}

Write-Host ""
if ($ready) {
  Write-Host "Looks ready. Start the miner when you want."
} else {
  Write-Host "Not ready for mining yet."
}
