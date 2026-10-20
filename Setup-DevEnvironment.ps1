<#
.SYNOPSIS
    Installs the tools needed to work on ProgressRecord on a new Windows PC.

.DESCRIPTION
    Installs PowerShell 7, Git, VS Code and Arduino IDE 2 with winget, skipping
    anything that is already installed. Then sets the execution policy, installs
    Pester 5 and PSScriptAnalyzer for PowerShell 7 and adds the VS Code extensions.

    Works from Windows PowerShell 5.1, so it can run on a PC that doesn't have
    PowerShell 7 yet. Run it from a normal (not admin) window, winget asks for
    admin rights itself when an installer needs them:

        powershell -ExecutionPolicy Bypass -File .\Setup-DevEnvironment.ps1

.PARAMETER SkipArduino
    Leaves out Arduino IDE, for a PC that will never have the display plugged in.
#>
[CmdletBinding()]
param(
    [switch]$SkipArduino
)

$ErrorActionPreference = 'Stop'

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    winget list --id $Id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $Name is already installed" -ForegroundColor DarkGray
        return
    }

    Write-Host "  Installing $Name..." -ForegroundColor Cyan
    winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget could not install $Name (exit code $LASTEXITCODE)"
    }
}

function Update-SessionPath {
    # New installs add themselves to PATH, but this window only sees that after a restart
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget was not found. Install or update "App Installer" from the Microsoft Store and run this script again.'
}

Write-Host "`n1. Programs" -ForegroundColor Yellow
Install-WingetPackage -Id 'Microsoft.PowerShell' -Name 'PowerShell 7'
Install-WingetPackage -Id 'Git.Git' -Name 'Git'
Install-WingetPackage -Id 'Microsoft.VisualStudioCode' -Name 'VS Code'
if (-not $SkipArduino) {
    Install-WingetPackage -Id 'ArduinoSA.IDE.stable' -Name 'Arduino IDE 2'
}
Update-SessionPath

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh) {
    throw 'PowerShell 7 was installed but pwsh is not found yet. Open a new window and run this script again.'
}

Write-Host "`n2. Execution policy" -ForegroundColor Yellow
# 5.1 and 7 keep this setting in different places, so set it in both
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
& $pwsh.Source -NoProfile -Command 'Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force'
Write-Host '  Set to RemoteSigned for your user' -ForegroundColor DarkGray

Write-Host "`n3. PowerShell modules" -ForegroundColor Yellow
# Installed through pwsh so they end up in the PowerShell 7 module folder
& $pwsh.Source -NoProfile -Command @'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if (-not (Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0.0')) {
        Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
    }
    if (-not (Get-Module PSScriptAnalyzer -ListAvailable)) {
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
    }
    Get-Module Pester, PSScriptAnalyzer -ListAvailable |
        Sort-Object Name, Version -Descending |
        Group-Object Name |
        ForEach-Object { '  {0} {1}' -f $_.Name, $_.Group[0].Version }
'@
if ($LASTEXITCODE -ne 0) {
    throw 'Installing the PowerShell modules failed, see the error above.'
}

Write-Host "`n4. VS Code extensions" -ForegroundColor Yellow
if (Get-Command code -ErrorAction SilentlyContinue) {
    foreach ($extension in 'ms-vscode.powershell', 'pspester.pester-test') {
        code --install-extension $extension --force
    }
}
else {
    Write-Warning 'The code command was not found. Install the PowerShell and Pester Tests extensions by hand.'
}

Write-Host "`nDone. Still to do by hand:" -ForegroundColor Green
Write-Host '  - Sign in to GitHub Desktop (or run git config for your name and email)'
Write-Host '  - Clone the ProgressRecord repo'
Write-Host '  - In VS Code, pick PowerShell 7 under "PowerShell: Show Session Menu"'
if (-not $SkipArduino) {
    Write-Host '  - In Arduino IDE, add the esp32 boards and the TFT_eSPI and ArduinoJson libraries (guide step 10 and 11)'
}
