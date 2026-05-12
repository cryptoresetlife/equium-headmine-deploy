# Equium head-mine deploy kit

Portable Windows + WSL scripts for building and running the Equium GPU miner,
with the CPU CLI miner kept as a fallback.

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

4. Build the miners in WSL:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-wsl.ps1
   ```

   This builds both `equium-gpu-miner` and the CPU `equium-miner`.

5. Import the website wallet private key locally:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\import-official-wallet.ps1
   ```

   The script refuses to save if the derived address does not match
   `EQUIUM_EXPECTED_PUBKEY`.

6. Check chain and wallet readiness:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\check-equium-wsl.ps1
   ```

7. Check the GPU path:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\check-equium-gpu-wsl.ps1
   ```

   If auto-probing gets stuck on Vulkan but GL works, set
   `EQUIUM_GPU_BACKEND = "gl"` in `config.env.ps1`.

8. Start GPU mining:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\start-equium-gpu-wsl.ps1
   ```

   The default GPU mode is hybrid: GPU leaf generation plus CPU Wagner rounds.
   Only set `EQUIUM_GPU_FULL = "1"` after `equium-gpu-miner verify-rounds`
   passes on that machine.

Multi-lane GPU mining:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-equium-gpu-multi-wsl.ps1
```

This starts `EQUIUM_GPU_MULTI_LANES` GPU miner processes and opens a monitor
window that sums the latest H/s from each lane. It does not stop an existing
CPU miner. Stop only the GPU lanes with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-equium-gpu-multi-wsl.ps1
```

CPU fallback:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\start-equium-wsl.ps1
   ```

Stop with `Ctrl+C`.

## Security notes

- Do not commit `config.env.ps1`.
- Do not commit `official-id.json`, wallet JSON files, seeds, or private keys.
- Use a hot wallet with only enough SOL for mining fees.
- If you accidentally pushed an RPC key, rotate it in your RPC provider dashboard.
