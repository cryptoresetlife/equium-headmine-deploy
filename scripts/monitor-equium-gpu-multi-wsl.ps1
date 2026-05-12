param(
  [string]$LogDir = "",
  [int]$RefreshSeconds = 3
)

. "$PSScriptRoot\common.ps1"
Import-EquiumConfig
$host.UI.RawUI.WindowTitle = "Equium GPU total hashrate"

if (-not $LogDir) {
  $LogDir = if ($env:EQUIUM_GPU_MULTI_LOG_DIR) { $env:EQUIUM_GPU_MULTI_LOG_DIR } else { "~/.config/equium/gpu-multi" }
}

function Convert-RateToH([double]$Value, [string]$Unit) {
  if ($Unit -eq "kH/s") { return $Value * 1000.0 }
  return $Value
}

function Format-Rate([double]$RateH) {
  if ($RateH -ge 1000.0) { return ("{0:n1} kH/s" -f ($RateH / 1000.0)) }
  return ("{0:n1} H/s" -f $RateH)
}

$hostLogDir = Convert-WslPathToUnc $LogDir
while ($true) {
  Clear-Host
  Write-Host ("Equium GPU multi-lane monitor  {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Write-Host "Logs: $LogDir"
  Write-Host ""

  $rows = @()
  if (Test-Path -LiteralPath $hostLogDir) {
    $pidFiles = Get-ChildItem -LiteralPath $hostLogDir -Filter "worker-*.pid" -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($pidFile in $pidFiles) {
      $lane = [int]([regex]::Match($pidFile.BaseName, "\d+").Value)
      $pidText = "$((Get-Content -LiteralPath $pidFile.FullName -ErrorAction SilentlyContinue | Select-Object -First 1))".Trim()
      $alive = $false
      if ($pidText) {
        $alive = ((& wsl.exe -- bash -lc "kill -0 $pidText 2>/dev/null; echo `$?").Trim()) -eq "0"
      }

      $logPath = Join-Path $hostLogDir ("worker-{0:d2}.log" -f $lane)
      $rateH = 0.0
      $last = "(waiting for log)"
      if (Test-Path -LiteralPath $logPath) {
        $tail = @(Get-Content -LiteralPath $logPath -Tail 120 -ErrorAction SilentlyContinue)
        $nonEmpty = @($tail | Where-Object { $_.Trim() })
        if ($nonEmpty.Count -gt 0) { $last = $nonEmpty[-1] }
        for ($i = $tail.Count - 1; $i -ge 0; $i--) {
          $m = [regex]::Match($tail[$i], "([0-9]+(?:\.[0-9]+)?)\s*(kH/s|H/s)")
          if ($m.Success) {
            $rateH = Convert-RateToH ([double]$m.Groups[1].Value) $m.Groups[2].Value
            break
          }
        }
      }

      $rows += [pscustomobject]@{
        Lane = $lane
        PID = $pidText
        Status = if ($alive) { "running" } else { "exited" }
        Rate = Format-Rate $rateH
        RateH = $rateH
        Last = $last
      }
    }
  }

  if ($rows.Count -eq 0) {
    Write-Host "No GPU lane pid files found yet."
  } else {
    $totalH = ($rows | Measure-Object -Property RateH -Sum).Sum
    $running = @($rows | Where-Object { $_.Status -eq "running" }).Count
    Write-Host ("GPU lanes: {0}/{1} running" -f $running, $rows.Count)
    Write-Host ("Total GPU rate: {0}" -f (Format-Rate $totalH))
    $cpu = (& wsl.exe -- bash -lc "pgrep -af './target/release/equium-miner ' | head -1 || true").Trim()
    if ($cpu) { Write-Host "CPU miner: running" } else { Write-Host "CPU miner: not detected" }
    Write-Host ""
    $rows |
      Select-Object Lane, PID, Status, Rate, @{Name="Last"; Expression={ if ($_.Last.Length -gt 96) { $_.Last.Substring(0, 96) + "..." } else { $_.Last } }} |
      Format-Table -AutoSize
  }

  Write-Host ""
  Write-Host "Refresh: ${RefreshSeconds}s. Close this window to stop monitoring only."
  Start-Sleep -Seconds $RefreshSeconds
}

