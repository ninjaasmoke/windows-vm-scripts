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

function Install-WingetPackage($name, $id) {
  Write-Host "`n=== $name ==="
  & winget list --id $id --exact --accept-source-agreements 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Already installed. Skipping."
    return
  }

  & winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0) {
    throw "winget failed to install $name (ExitCode=$LASTEXITCODE)"
  }
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

  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install or update App Installer, then run this script again."
  }

  $wingetApps = @(
    @{ Name = "Neovim";               Id = "Neovim.Neovim" },
    @{ Name = "fd";                   Id = "sharkdp.fd" },
    @{ Name = "ripgrep";              Id = "BurntSushi.ripgrep.MSVC" },
    @{ Name = "JetBrainsMono Nerd Font"; Id = "DEVCOM.JetBrainsMonoNerdFont" }
  )

  foreach ($app in $wingetApps) {
    Install-WingetPackage $app.Name $app.Id
  }

  $nvimConfig = Join-Path $env:LOCALAPPDATA "nvim"
  Write-Host "`n=== LazyVim ==="
  $starterZip = Join-Path $workDir "lazyvim-starter.zip"
  $starterDir = Join-Path $workDir "starter"
  Download-File "https://github.com/LazyVim/starter/archive/refs/heads/main.zip" $starterZip
  Expand-Archive -LiteralPath $starterZip -DestinationPath $starterDir -Force

  $starterRoot = Join-Path $starterDir "starter-main"
  if (-not (Test-Path -LiteralPath $starterRoot)) {
    throw "LazyVim starter archive did not contain the expected directory."
  }

  if (Test-Path -LiteralPath $nvimConfig) {
    $backup = "$nvimConfig.backup-$(Get-Date -Format 'yyyyMMdd-HHmmssfff')"
    Copy-Item -LiteralPath $nvimConfig -Destination $backup -Recurse
    Remove-Item -LiteralPath $nvimConfig -Recurse -Force
    Write-Host "Backed up the existing configuration to $backup."
  }

  Copy-Item -LiteralPath $starterRoot -Destination $nvimConfig -Recurse
  Remove-Item -LiteralPath (Join-Path $nvimConfig ".git") -Recurse -Force -ErrorAction SilentlyContinue

  $pluginsDir = Join-Path $nvimConfig "lua\plugins"
  New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
  @'
return {
  { import = "lazyvim.plugins.extras.editor.neo-tree" },
  { import = "lazyvim.plugins.extras.editor.telescope" },
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
    },
    opts = {
      kind = "tab",
    },
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Git status (Neogit)" },
    },
  },
  {
    "sindrets/diffview.nvim",
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git diff (Diffview)" },
    },
  },
}
'@ | Set-Content -LiteralPath (Join-Path $pluginsDir "git.lua") -Encoding UTF8

  Write-Host "Installed LazyVim starter in $nvimConfig."

  Write-Host "`nDone."
}
finally {
  if (Test-Path $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}