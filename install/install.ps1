#Requires -Version 5.1
# install.ps1
# Windows installer for tito-pdf.
#
# This installer:
# - Copies tito-pdf + requirements into a user-writable install root
# - Creates a dedicated Python venv and installs requirements
# - Optionally creates shims in a user bin dir (PowerShell + CMD + Git Bash)
# - Writes BUILD_INFO and install manifests for clean uninstall

[CmdletBinding()]
param(
    # Install root (default: %LOCALAPPDATA%\\Programs\\_runtime\\tito-pdf)
    [string]$InstallRoot = "$env:LOCALAPPDATA\\Programs\\_runtime\\tito-pdf",

    # User bin directory for shims (default: %LOCALAPPDATA%\\Programs)
    [string]$UserBinDir = "$env:LOCALAPPDATA\\Programs",

    # Repo root (defaults to parent of this script directory)
    [string]$RepoRoot,

    # Create shims in UserBinDir and ensure User PATH contains UserBinDir (default: true)
    [switch]$SetupShims,

    # Attempt to install missing system dependencies (qpdf, tesseract)
    # via winget/choco when available (default: true)
    [switch]$InstallSystemDeps,

    # Proceed without prompts
    [switch]$Force
)

if (-not $PSBoundParameters.ContainsKey('SetupShims')) {
    $SetupShims = $true
}

if (-not $PSBoundParameters.ContainsKey('InstallSystemDeps')) {
    $InstallSystemDeps = $true
}

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
}

$titoPdfSrc = Join-Path $RepoRoot "tito-pdf"
$requirementsSrc = Join-Path $RepoRoot "requirements.txt"

if (-not (Test-Path -LiteralPath $titoPdfSrc)) {
    Write-Host "[ERROR] tito-pdf script not found in repo: $titoPdfSrc" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $requirementsSrc)) {
    Write-Host "[ERROR] requirements.txt not found in repo: $requirementsSrc" -ForegroundColor Red
    exit 1
}

function Write-LFFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )

    $normalized = $Content -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Normalize-PathSegment {
    param([Parameter(Mandatory=$true)][string]$Path)
    $p = $Path.Trim()
    while ($p.EndsWith('\\') -or $p.EndsWith('/')) {
        $p = $p.Substring(0, $p.Length - 1)
    }
    return $p
}

function Add-ToUserPath {
    param([Parameter(Mandatory=$true)][string]$Dir)

    $dirNorm = Normalize-PathSegment -Path $Dir
    if (-not $dirNorm) { return $false }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($userPath) {
        $parts = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
    }

    foreach ($p in $parts) {
        if ((Normalize-PathSegment -Path $p).Equals($dirNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    $newPath = if ($userPath -and $userPath.Trim() -ne "") { $userPath + ";" + $Dir } else { $Dir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

    # Refresh current session too
    if ($env:Path -notlike "*$Dir*") {
        $env:Path = $env:Path.TrimEnd(';') + ";" + $Dir
    }
    return $true
}

function Read-InstallManifest {
    param([Parameter(Mandatory=$true)][string]$Path)
    $info = @{
        files = @()
        dirs = @()
        props = @{}
    }
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $k = $matches[1]
            $v = $matches[2]
            if ($k -eq 'file') { $info.files += $v }
            elseif ($k -eq 'dir') { $info.dirs += $v }
            else { $info.props[$k] = $v }
        }
    }
    return $info
}

function Remove-PathIfExists {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not $Path) { return }
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction Stop } catch {}
    }
}

function Resolve-Python {
    $cmd = Get-Command python3 -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return @{ exe = $cmd.Source; args = @() } }

    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return @{ exe = $cmd.Source; args = @() } }

    $cmd = Get-Command py -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return @{ exe = $cmd.Source; args = @('-3') } }

    return $null
}

function Command-Path {
    param([Parameter(Mandatory=$true)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $null
}

function Install-WithWinget {
    param(
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string[]]$IdCandidates
    )

    $winget = Command-Path -Name 'winget'
    if (-not $winget) { return $false }

    foreach ($id in $IdCandidates) {
        if (-not $id -or $id.Trim() -eq "") { continue }

        Write-Host "[INFO] Installing $DisplayName via winget (id=$id) ..." -ForegroundColor Cyan

        # Prefer per-user installs when supported. Retry with progressively simpler
        # flags for compatibility across winget versions/packages.
        & $winget install --id $id -e --scope user --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -eq 0) { return $true }

        & $winget install --id $id -e --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -eq 0) { return $true }

        & $winget install --id $id -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { return $true }

        Write-Host "[WARN] winget install failed for id=$id (exit=$LASTEXITCODE)." -ForegroundColor Yellow
    }

    return $false
}

function Install-WithChoco {
    param(
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string[]]$PkgCandidates
    )

    $choco = Command-Path -Name 'choco'
    if (-not $choco) { return $false }

    foreach ($pkg in $PkgCandidates) {
        if (-not $pkg -or $pkg.Trim() -eq "") { continue }

        Write-Host "[INFO] Installing $DisplayName via choco (pkg=$pkg) ..." -ForegroundColor Cyan
        & $choco install -y $pkg
        if ($LASTEXITCODE -eq 0) { return $true }

        Write-Host "[WARN] choco install failed for pkg=$pkg (exit=$LASTEXITCODE)." -ForegroundColor Yellow
    }

    return $false
}

function Ensure-SystemDeps {
    $qpdf = Command-Path -Name 'qpdf'
    $tesseract = Command-Path -Name 'tesseract'

    $missing = @()
    if (-not $qpdf) { $missing += 'qpdf' }
    if (-not $tesseract) { $missing += 'tesseract' }

    if ($missing.Count -eq 0) {
        return
    }

    Write-Host "" 
    Write-Host "[WARN] Missing system dependencies: $($missing -join ', ')" -ForegroundColor Yellow

    $hasWinget = [bool](Command-Path -Name 'winget')
    $hasChoco = [bool](Command-Path -Name 'choco')

    if (-not $hasWinget -and -not $hasChoco) {
        Write-Host "[WARN] Neither winget nor choco found in PATH; skipping auto-install." -ForegroundColor Yellow
        Write-Host "[INFO] Install these deps manually (recommended): qpdf, tesseract" -ForegroundColor Cyan
        return
    }

    Write-Host "[INFO] Attempting best-effort installation via winget/choco..." -ForegroundColor Cyan

    foreach ($dep in $missing) {
        switch ($dep) {
            'qpdf' {
                $ok = Install-WithWinget -DisplayName 'qpdf' -IdCandidates @('QPDF.QPDF', 'qpdf.qpdf')
                if (-not $ok) { $ok = Install-WithChoco -DisplayName 'qpdf' -PkgCandidates @('qpdf') }
            }
            'tesseract' {
                $ok = Install-WithWinget -DisplayName 'Tesseract OCR' -IdCandidates @('UB-Mannheim.TesseractOCR', 'Tesseract-OCR.Tesseract')
                if (-not $ok) { $ok = Install-WithChoco -DisplayName 'Tesseract OCR' -PkgCandidates @('tesseract', 'tesseract-ocr') }
            }
            default {
                Write-Host "[WARN] No installer mapping for dependency: $dep" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "" 
    Write-Host "[INFO] If you installed new system deps, open a NEW terminal so PATH updates take effect." -ForegroundColor Cyan
}

$py = Resolve-Python
if (-not $py) {
    Write-Host "[ERROR] Python is required (python/python3/py not found in PATH)." -ForegroundColor Red
    exit 1
}

if ($InstallSystemDeps) {
    try { Ensure-SystemDeps } catch {
        Write-Host "[WARN] System dependency installation failed (continuing): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# qpdf is required for PDF conversion.
$qpdf = Command-Path -Name 'qpdf'
if (-not $qpdf) {
    Write-Host "[ERROR] qpdf is required for PDF conversion but was not found on PATH." -ForegroundColor Red
    Write-Host "[INFO] Install qpdf and re-run this installer." -ForegroundColor Cyan
    exit 1
}

$libexecDir = Join-Path $InstallRoot "libexec"
$venvDir = Join-Path $libexecDir ".venv"
$installManifestPath = Join-Path $libexecDir "INSTALL_MANIFEST"
$userManifestPath = Join-Path $UserBinDir "tito-pdf.INSTALL_MANIFEST"

# Remove existing install if present
$existingManifest = $null
if (Test-Path -LiteralPath $userManifestPath) {
    $existingManifest = $userManifestPath
} elseif (Test-Path -LiteralPath $installManifestPath) {
    $existingManifest = $installManifestPath
}

if ($existingManifest) {
    Write-Host ""
    Write-Host "[WARN] Existing tito-pdf install manifest found at $existingManifest" -ForegroundColor Yellow
    if (-not $Force) {
        $resp = Read-Host "Existing tito-pdf install will be removed. Continue? [y/N]"
        if ($resp -notmatch '^[Yy]$') { exit 0 }
    }

    $info = Read-InstallManifest -Path $existingManifest
    foreach ($p in $info.files) { Remove-PathIfExists -Path $p }
    foreach ($d in $info.dirs) { Remove-PathIfExists -Path $d }
} elseif ((Test-Path -LiteralPath $InstallRoot) -or (Test-Path -LiteralPath $libexecDir)) {
    Write-Host ""
    Write-Host "[WARN] Existing tito-pdf install directories detected in $InstallRoot" -ForegroundColor Yellow
    if (-not $Force) {
        $resp = Read-Host "Existing tito-pdf install will be removed. Continue? [y/N]"
        if ($resp -notmatch '^[Yy]$') { exit 0 }
    }

    Remove-PathIfExists -Path $libexecDir
}

# Create directories
New-Item -ItemType Directory -Path $libexecDir -Force | Out-Null

# Copy runtime
Copy-Item -LiteralPath $titoPdfSrc -Destination (Join-Path $libexecDir "tito-pdf") -Force
Copy-Item -LiteralPath $requirementsSrc -Destination (Join-Path $libexecDir "requirements.txt") -Force

# Create venv + install deps
Write-Host "[INFO] Creating venv at: $venvDir" -ForegroundColor Cyan
& $py.exe @($py.args) -m venv $venvDir

$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvPip = Join-Path $venvDir "Scripts\pip.exe"

Write-Host "[INFO] Installing Python dependencies..." -ForegroundColor Cyan
& $venvPython -m pip install --upgrade pip setuptools wheel | Out-Null
& $venvPip install -r (Join-Path $libexecDir "requirements.txt")

# BUILD_INFO
$builtAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$gitCommit = ""
$gitDescribe = ""
if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $inside = & git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null
        if ($inside -and $inside.Trim() -eq "true") {
            $gitCommit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null | Select-Object -First 1)
            $gitDescribe = (& git -C $RepoRoot describe --tags --always --dirty 2>$null | Select-Object -First 1)
        }
    } catch {}
}

$buildInfoPath = Join-Path $libexecDir "BUILD_INFO"
$buildInfoLines = @("built_at_utc=$builtAtUtc")
if ($gitCommit) { $buildInfoLines += "git_commit=$gitCommit" }
if ($gitDescribe) { $buildInfoLines += "git_describe=$gitDescribe" }
Write-LFFile -Path $buildInfoPath -Content (($buildInfoLines -join "`n") + "`n")

# Shims
$shimBash = $null
$shimPs1 = $null
$shimCmd = $null
$pathAdded = $false

if ($SetupShims) {
    New-Item -ItemType Directory -Path $UserBinDir -Force | Out-Null

    $shimBash = Join-Path $UserBinDir "tito-pdf"
    $shimPs1 = Join-Path $UserBinDir "tito-pdf.ps1"
    $shimCmd = Join-Path $UserBinDir "tito-pdf.cmd"

    # Git Bash shim
    Write-LFFile -Path $shimBash -Content (
@"#!/usr/bin/env bash
exec "$(dirname "$0")/tito-pdf.cmd" "$@"
"@ + "`n")

    # PowerShell shim
    Write-LFFile -Path $shimPs1 -Content (
@"#Requires -Version 5.1
\$ErrorActionPreference = 'Stop'
\$libexecDir = '$libexecDir'
\$py = Join-Path \$libexecDir '.venv\\Scripts\\python.exe'
\$script = Join-Path \$libexecDir 'tito-pdf'
& \$py \$script @args
exit \$LASTEXITCODE
"@ + "`n")

    # CMD shim
    Write-LFFile -Path $shimCmd -Content (
@"@echo off
set LIBEXEC_DIR=$libexecDir
"%LIBEXEC_DIR%\\.venv\\Scripts\\python.exe" "%LIBEXEC_DIR%\\tito-pdf" %*
"@ + "`n")

    $pathAdded = Add-ToUserPath -Dir $UserBinDir
}

# INSTALL_MANIFEST (libexec)
$installLines = @(
    "manifest_version=1",
    ("installed_at_utc=" + $builtAtUtc),
    ("install_root=" + $InstallRoot),
    ("libexec_dir=" + $libexecDir),
    ("venv_dir=" + $venvDir),
    ("repo_root=" + $RepoRoot),
    ("file=" + (Join-Path $libexecDir "tito-pdf")),
    ("file=" + (Join-Path $libexecDir "requirements.txt")),
    ("file=" + $buildInfoPath),
    ("file=" + $installManifestPath),
    ("dir=" + $libexecDir)
)
Write-LFFile -Path $installManifestPath -Content (($installLines -join "`n") + "`n")

# User manifest
if ($SetupShims) {
    $userLines = @(
        "manifest_version=1",
        ("installed_at_utc=" + $builtAtUtc),
        ("install_root=" + $InstallRoot),
        ("user_bin_dir=" + $UserBinDir),
        ("setup_shims=" + "true"),
        ("path_added=" + ($(if ($pathAdded) { "true" } else { "false" }))),
        ("file=" + $userManifestPath),
        ("file=" + $shimBash),
        ("file=" + $shimPs1),
        ("file=" + $shimCmd),
        ("file=" + $installManifestPath),
        ("dir=" + $libexecDir)
    )
    Write-LFFile -Path $userManifestPath -Content (($userLines -join "`n") + "`n")
}

Write-Host "" 
Write-Host "[OK]   tito-pdf installation complete" -ForegroundColor Green
Write-Host "" 
Write-Host "Verify (open a NEW terminal to refresh PATH):" -ForegroundColor Cyan
Write-Host "  tito-pdf --help" -ForegroundColor Cyan
