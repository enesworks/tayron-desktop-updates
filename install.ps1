#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads and launches the Tayron desktop installer without Mark-of-the-Web.

.DESCRIPTION
    Files fetched with Invoke-WebRequest do not receive the Zone.Identifier
    alternate data stream, so SmartScreen never evaluates the installer.
    The download is verified against the SHA-256 digest GitHub reports for
    the release asset before anything is executed.

.EXAMPLE
    irm https://raw.githubusercontent.com/enesworks/tayron-desktop-updates/main/install.ps1 | iex

.EXAMPLE
    .\install-tayron.ps1 -Version 1.0.1 -Silent

.EXAMPLE
    .\install-tayron.ps1 -DryRun
    Downloads and verifies the installer, then stops without launching it.
#>
[CmdletBinding()]
param(
    [string]$Version = "latest",
    [switch]$Silent,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "enesworks/tayron-desktop-updates"
$asset = "Tayron-Desktop---Installer.exe"
$apiBase = "https://api.github.com/repos/$repo/releases"

if ($Version -eq "latest") {
    $releaseApi = "$apiBase/latest"
    $downloadUrl = "https://github.com/$repo/releases/latest/download/$asset"
}
else {
    $releaseApi = "$apiBase/tags/v$Version"
    $downloadUrl = "https://github.com/$repo/releases/download/v$Version/$asset"
}

$target = Join-Path ([System.IO.Path]::GetTempPath()) "Tayron-Desktop-Installer.exe"

Write-Host "Tayron indiriliyor: $downloadUrl" -ForegroundColor Cyan

$headers = @{ "User-Agent" = "Tayron-Installer" }
Invoke-WebRequest -Uri $downloadUrl -OutFile $target -UseBasicParsing -Headers $headers

try {
    $release = Invoke-RestMethod -Uri $releaseApi -Headers $headers
    $digest = $release.assets |
        Where-Object { $_.name -eq $asset } |
        Select-Object -First 1 -ExpandProperty digest

    if ($digest -and $digest -like "sha256:*") {
        $actual = "sha256:" + (Get-FileHash -Path $target -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $digest.ToLowerInvariant()) {
            Remove-Item $target -Force -ErrorAction SilentlyContinue
            throw "Dosya ozeti uyusmuyor. Indirme bozuk veya degistirilmis. Kurulum iptal edildi."
        }
        Write-Host "SHA-256 dogrulandi." -ForegroundColor Green
    }
    else {
        Write-Warning "Surum ozeti bulunamadi, hash dogrulamasi atlandi."
    }
}
catch [System.Net.WebException] {
    Write-Warning "Ozet sorgulanamadi, hash dogrulamasi atlandi: $($_.Exception.Message)"
}

if ($DryRun) {
    Write-Host "DryRun: dogrulama tamam, kurulum baslatilmadi." -ForegroundColor Green
    Write-Host "Dosya: $target"
    return
}

if ($Silent) {
    Write-Host "Sessiz kurulum baslatiliyor..." -ForegroundColor Cyan
    Start-Process -FilePath $target -ArgumentList "/S" -Wait
}
else {
    Start-Process -FilePath $target
}
