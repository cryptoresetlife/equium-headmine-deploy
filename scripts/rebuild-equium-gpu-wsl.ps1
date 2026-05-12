. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

$repo = if ($env:EQUIUM_UPSTREAM_REPO) { $env:EQUIUM_UPSTREAM_REPO } else { "https://github.com/HannaPrints/equium.git" }
$projectDir = Get-ProjectDir

$rebuild = @'
set -euo pipefail

repo="$1"
project_dir="$2"
export PATH="$HOME/.cargo/bin:$PATH"
project_dir="${project_dir/#\~/$HOME}"

if [ ! -d "$project_dir/.git" ]; then
  git clone "$repo" "$project_dir"
else
  git -C "$project_dir" stash push -m equium-deploy-gpu-build-patch -- clients/cli-miner/Cargo.toml clients/gpu-miner/Cargo.toml Cargo.lock >/dev/null || true
  git -C "$project_dir" pull --ff-only
fi

python3 - "$project_dir" <<'PY'
from pathlib import Path
import sys

project = Path(sys.argv[1])
line = 'solana-secp256r1-program = { version = "2.2.4", features = ["openssl-vendored"] }'

def add_line(manifest: Path, marker: str):
    text = manifest.read_text()
    if line in text:
        return
    if marker not in text:
        raise SystemExit(f"could not find dependency marker in {manifest}")
    manifest.write_text(text.replace(marker, marker + line + "\n"))

add_line(project / "clients" / "gpu-miner" / "Cargo.toml", 'solana-client = "2.1"\n')
PY

cargo build --manifest-path "$project_dir/Cargo.toml" -p equium-gpu-miner --release
"$project_dir/target/release/equium-gpu-miner" verify-cpu
"$project_dir/target/release/equium-gpu-miner" --version
'@

$rebuildB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rebuild))
$cmd = "printf '%s' '$rebuildB64' | base64 -d | bash -s -- '$repo' '$projectDir'"
wsl.exe -- bash -lc $cmd

