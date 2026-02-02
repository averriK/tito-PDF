#Requires -Version 5.1
# uninstall.ps1
# Windows uninstaller for tito-pdf.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # User bin directory where shims/manifest live
    [string]$UserBinDir = "$env:LOCALAPPDATA\Programs",

    # Remove UserBinDir from User PATH (opt-in)
    [switch]$RemoveUserBinFromPath
)

function Normalize-PathSegment {
    param([Parameter(Mandatory=$true)][string]$Path)
    $p = $Path.Trim()
    while ($p.EndsWith('\\') -or $p.EndsWith('/')) {
        $p = $p.Substring(0, $p.Length - 1)
    }
    return $p
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

function Remove-FromUserPath {
    param([Parameter(Mandatory=$true)][string]$Dir)

    $dirNorm = Normalize-PathSegment -Path $Dir
    if (-not $dirNorm) { return }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return }

    $parts = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
    $kept = New-Object System.Collections.Generic.List[string]

    foreach ($p in $parts) {
        $pNorm = Normalize-PathSegment -Path $p
        if ($pNorm -and ($pNorm.Equals($dirNorm, [System.StringComparison]::OrdinalIgnoreCase))) {
            continue
        }
        $kept.Add($p) | Out-Null
    }

    $newPath = ($kept -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}

function Remove-PathIfExists {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not $Path) { return $false }
    if (Test-Path -LiteralPath $Path) {
        try {
            if ($PSCmdlet.ShouldProcess($Path, 'Remove')) {
                Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction Stop
            }
            return $true
        } catch {
            return $false
        }
    }
    return $false
}

$userManifestPath = Join-Path $UserBinDir "tito-pdf.INSTALL_MANIFEST"
$manifestInfo = $null

if (Test-Path -LiteralPath $userManifestPath) {
    $manifestInfo = Read-InstallManifest -Path $userManifestPath
}

if (-not $manifestInfo) {
    Write-Host ""
    Write-Host "[WARN] tito-pdf install manifest not found at $userManifestPath" -ForegroundColor Yellow

    $installRoot = "$env:LOCALAPPDATA\Programs\_runtime\tito-pdf"
    $libexecDir = Join-Path $installRoot "libexec"

    $targets = @(
        (Join-Path $UserBinDir "tito-pdf"),
        (Join-Path $UserBinDir "tito-pdf.ps1"),
        (Join-Path $UserBinDir "tito-pdf.cmd")
    )

    foreach ($p in $targets) { Remove-PathIfExists -Path $p | Out-Null }
    Remove-PathIfExists -Path $libexecDir | Out-Null

    if ($RemoveUserBinFromPath) {
        Remove-FromUserPath -Dir $UserBinDir
    }
} else {
    $removedAny = $false
    foreach ($p in $manifestInfo.files) {
        if (Remove-PathIfExists -Path $p) { $removedAny = $true }
    }
    foreach ($d in $manifestInfo.dirs) {
        if (Remove-PathIfExists -Path $d) { $removedAny = $true }
    }

    if (-not $removedAny) {
        Write-Host "[INFO] No tito-pdf files found to remove." -ForegroundColor Cyan
    }

    if ($RemoveUserBinFromPath) {
        if ($manifestInfo.props.ContainsKey("path_added") -and $manifestInfo.props["path_added"] -ne "true") {
            Write-Host "[INFO] PATH not modified by installer; skipping PATH removal." -ForegroundColor Cyan
        } else {
            $binDir = if ($manifestInfo.props.ContainsKey("user_bin_dir")) { $manifestInfo.props["user_bin_dir"] } else { $UserBinDir }
            Remove-FromUserPath -Dir $binDir
        }
    } else {
        Write-Host "[INFO] Leaving User PATH unchanged. Use -RemoveUserBinFromPath to remove: $UserBinDir" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "[OK]   tito-pdf uninstall complete" -ForegroundColor Green
