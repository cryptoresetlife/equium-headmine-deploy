param(
  [string]$ExpectedAddress = "",
  [string]$OutputPath = ""
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

if (-not $ExpectedAddress) {
  $ExpectedAddress = $env:EQUIUM_EXPECTED_PUBKEY
}
if (-not $ExpectedAddress -or $ExpectedAddress -eq "YOUR_SOLANA_WALLET_ADDRESS") {
  throw "Set EQUIUM_EXPECTED_PUBKEY in config.env.ps1 first."
}

if (-not $OutputPath) {
  $keypair = if ($env:EQUIUM_KEYPAIR) { $env:EQUIUM_KEYPAIR } else { "~/.config/equium/official-id.json" }
  $OutputPath = Convert-WslPathToUnc $keypair
}

$importScript = Join-Path $PSScriptRoot "import-official-wallet.py"

Write-Host "Paste the official website wallet private key below."
Write-Host "Supported formats: Solana JSON byte array, base58 64-byte secret key, or base58 32-byte seed."
Write-Host "The script will refuse to save it unless the derived address is $ExpectedAddress."
$secure = Read-Host "Private key (hidden)" -AsSecureString

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $secret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if (-not $secret) {
  throw "No private key was entered."
}

$derivedOutput = $secret | & python $importScript $ExpectedAddress $OutputPath 2>&1
$importExit = $LASTEXITCODE
Remove-Variable secret -ErrorAction SilentlyContinue

if ($importExit -ne 0) {
  throw "Wallet import failed:`n$($derivedOutput -join "`n")"
}

$derived = ($derivedOutput | Select-Object -Last 1).Trim()
wsl.exe -- bash -lc "chmod 700 ~/.config/equium; chmod 600 ~/.config/equium/official-id.json; chmod 644 ~/.config/equium/official-address.txt"

Write-Host ""
Write-Host "Imported wallet:"
Write-Host $derived
Write-Host "Saved keypair to WSL path: ~/.config/equium/official-id.json"
Write-Host "Use only a hot/mining wallet here. Keep large balances elsewhere."

