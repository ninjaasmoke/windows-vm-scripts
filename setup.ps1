#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$workDir = Join-Path $env:TEMP ("vm-setup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

function Download-File($url, $outFile) {
  Write-Host "Downloading: $url"
  Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
}

function Run-Installer($path, $arguments) {
  Write-Host "Installing: $path $arguments"
  $p = Start-Process -FilePath $path -ArgumentList $arguments -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "Installer failed: $path (ExitCode=$($p.ExitCode))" }
}

function Exists-Any($patterns) {
  foreach ($p in $patterns) {
    if (Test-Path $p) { return $true }
    $m = Get-ChildItem -Path $p -ErrorAction SilentlyContinue
    if ($m) { return $true }
  }
  return $false
}

$apps = @(
  @{
    Name  = "Notepad++"
    Url   = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9/npp.8.9.Installer.x64.exe"
    File  = "npp.8.9.Installer.x64.exe"
    Args  = "/S"
    Check = @("$env:ProgramFiles\Notepad++\notepad++.exe")
  },
  @{
    Name  = "gVim"
    Url   = "https://www.vim.org/downloads/gvim_9.1.1825_x64.exe"
    File  = "gvim_9.1.1825_x64.exe"
    Args  = "/S"
    Check = @("$env:ProgramFiles\Vim\vim*\gvim.exe")
  },
  @{
    Name  = "Everything (with service)"
    Url   = "https://www.voidtools.com/Everything-1.4.1.1030.x64-Setup.exe"
    File  = "Everything-1.4.1.1030.x64-Setup.exe"
    Args  = '/S -install-options "-app-data -install-service -install-start-menu-shortcuts -install-efu-association -install-run-on-system-startup -install-language 1033"'
    Check = @("$env:ProgramFiles\Everything\Everything.exe")
  }
)

try {
  foreach ($app in $apps) {
    Write-Host "`n=== $($app.Name) ==="
    if (Exists-Any $app.Check) {
      Write-Host "Already installed. Skipping."
      continue
    }

    $installerPath = Join-Path $workDir $app.File
    Download-File $app.Url $installerPath
    Run-Installer $installerPath $app.Args

    if (-not (Exists-Any $app.Check)) {
      Write-Host "Installer exited OK but detection didn't confirm. Verify manually."
    } else {
      Write-Host "Installed OK."
    }
  }

  Write-Host "`nDone."
}
finally {
  if (Test-Path $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}