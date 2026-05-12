# Equium head-mine deploy kit

Portable Windows + WSL scripts for building and running the Equium CLI miner.

This repo intentionally does not contain:

- wallet private keys
- RPC API keys
- compiled binaries
- the upstream Equium source tree

## Quick start on a new Windows PC

1. Install WSL Ubuntu if needed:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

2. Clone this deploy repo and enter it:

   ```powershell
   git clone https://github.com/YOUR_NAME/equium-headmine-deploy.git
   cd equium-headmine-deploy
   ```

3. Create local config:

   ```powershell
   Copy-Item .\config.env.example.ps1 .\config.env.ps1
   notepad .\config.env.ps1
   ```

   Fill:

   - `EQUIUM_RPC_URL`: your private Solana mainnet RPC URL
   - `EQUIUM_EXPECTED_PUBKEY`: the mining wallet address you expect

4. Build the miner in WSL:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-wsl.ps1
   ```

5. Import the website wallet private key locally:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\import-official-wallet.ps1
   ```

   The script refuses to save if the derived address does not match
   `EQUIUM_EXPECTED_PUBKEY`.

6. Check readiness:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\check-equium-wsl.ps1
   ```

7. Start mining:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\start-equium-wsl.ps1
   ```

Stop with `Ctrl+C`.

## Security notes

- Do not commit `config.env.ps1`.
- Do not commit `official-id.json`, wallet JSON files, seeds, or private keys.
- Use a hot wallet with only enough SOL for mining fees.
- If you accidentally pushed an RPC key, rotate it in your RPC provider dashboard.

