# Copy this file to config.env.ps1, then edit config.env.ps1 only.
# config.env.ps1 is ignored by git.

# Use a private/paid Solana mainnet RPC for serious mining.
$env:EQUIUM_RPC_URL = "https://YOUR_SOLANA_MAINNET_RPC_URL"

# 0 means the miner will use all physical cores.
$env:EQUIUM_THREADS = "0"

# 0 means run forever.
$env:EQUIUM_MAX_BLOCKS = "0"

# WSL keypair path. Import the private key with:
# .\scripts\import-official-wallet.ps1
$env:EQUIUM_KEYPAIR = "~/.config/equium/official-id.json"

# Set this to the wallet address that must match the imported private key.
$env:EQUIUM_EXPECTED_PUBKEY = "YOUR_SOLANA_WALLET_ADDRESS"

# Build/source settings.
$env:EQUIUM_UPSTREAM_REPO = "https://github.com/HannaPrints/equium.git"
$env:EQUIUM_WSL_PROJECT_DIR = "~/equium-headmine"

