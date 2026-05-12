. "$PSScriptRoot\common.ps1"
Import-EquiumConfig

$repo = if ($env:EQUIUM_UPSTREAM_REPO) { $env:EQUIUM_UPSTREAM_REPO } else { "https://github.com/HannaPrints/equium.git" }
$projectDir = Get-ProjectDir

$bootstrap = @'
set -euo pipefail

repo="$1"
project_dir="$2"

if ! command -v git >/dev/null 2>&1 || ! command -v gcc >/dev/null 2>&1 || ! command -v perl >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
  echo "Installing WSL build dependencies..."
  sudo apt-get update
  sudo apt-get install -y build-essential perl pkg-config git curl ca-certificates python3
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "Installing Rust toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

export PATH="$HOME/.cargo/bin:$PATH"

project_dir="${project_dir/#\~/$HOME}"
if [ ! -d "$project_dir/.git" ]; then
  git clone "$repo" "$project_dir"
else
  git -C "$project_dir" pull --ff-only
fi

python3 - "$project_dir" <<'PY'
from pathlib import Path
import sys

project = Path(sys.argv[1])
manifest = project / "clients" / "cli-miner" / "Cargo.toml"
text = manifest.read_text()
line = 'solana-secp256r1-program = { version = "2.2.4", features = ["openssl-vendored"] }'
marker = 'solana-program = { workspace = true }\n'
if line not in text:
    if marker not in text:
        raise SystemExit("could not find solana-program dependency marker")
    manifest.write_text(text.replace(marker, marker + line + "\n"))
PY

cargo build --manifest-path "$project_dir/Cargo.toml" -p equium-cli-miner --release
"$project_dir/target/release/equium-miner" --version
'@

$bootstrapB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bootstrap))
$cmd = "printf '%s' '$bootstrapB64' | base64 -d | bash -s -- '$repo' '$projectDir'"
wsl.exe -- bash -lc $cmd

