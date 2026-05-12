$ErrorActionPreference = "Stop"

function Get-DeployRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Import-EquiumConfig {
  $root = Get-DeployRoot
  $configPath = Join-Path $root "config.env.ps1"
  if (Test-Path -LiteralPath $configPath) {
    . $configPath
  } else {
    $example = Join-Path $root "config.env.example.ps1"
    throw "Missing config.env.ps1. Copy $example to config.env.ps1 and edit it first."
  }
}

function Get-WslDistroName {
  $name = (& wsl.exe -- bash -lc "printf %s `$WSL_DISTRO_NAME").Trim()
  if (-not $name) {
    throw "Could not detect WSL distro name."
  }
  return $name
}

function Get-WslHome {
  $homePath = (& wsl.exe -- bash -lc "printf %s `$HOME").Trim()
  if (-not $homePath) {
    throw "Could not detect WSL home directory."
  }
  return $homePath
}

function Convert-WslPathToUnc([string]$Path) {
  $distro = Get-WslDistroName
  $wslHome = Get-WslHome
  $expanded = Expand-WslPath $Path
  if ($expanded.StartsWith("/")) {
    return "\\wsl.localhost\$distro\" + $expanded.TrimStart("/").Replace("/", "\")
  }
  return $expanded
}

function Expand-WslPath([string]$Path) {
  if ($Path.StartsWith("~/")) {
    $wslHome = Get-WslHome
    return $wslHome.TrimEnd("/") + "/" + $Path.Substring(2)
  }
  return $Path
}

function Get-ProjectDir {
  if ($env:EQUIUM_WSL_PROJECT_DIR) {
    return $env:EQUIUM_WSL_PROJECT_DIR
  }
  return "~/equium-headmine"
}
