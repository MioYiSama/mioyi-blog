---
title: Shrink Docker WSL2 vhdx Disk Size
tags: [misc]
---

> Can also be used to clean up files for regular WSL distributions

When running Docker Desktop with the WSL2 backend on Windows, due to the nature of dynamic VHD disks (`docker_data.vhdx`), the host machine's disk space is not automatically released even if we delete a large number of useless images and containers in Docker. Often, the actual container usage is only around 20 GB, but the host's `.vhdx` file can swell to 130 GB, or even fill up the C drive.

## Core Solution: Directly Compress the VHDX

The most fundamental way to solve this problem is to shut down first, and then use Windows' `diskpart` tool to manually compress the bloated virtual disk file. Simply running `docker system prune` is not enough; you must actually compress the VHD file back.

### 1. Clean Up Internal Docker Junk (Optional)

Before compressing the disk, it's best to completely discard unnecessary images and zombie containers to free up space inside the container:

```bash
# View space usage
docker system df

# Clean up all dangling resources, stopped containers, and unused cache volumes
docker system prune -a --volumes
```

### 2. Shut Down WSL

After cleaning up, exit Docker Desktop completely. To detach the WSL VHDX from its mounted state, run the following in an **Administrator PowerShell**:

```powershell
wsl --shutdown
```

### 3. Compress the Disk

Continue by typing `diskpart` in the Administrator PowerShell to enter the interactive interface, then execute the following commands in order (replace with the actual path of your local `.vhdx`):

```powershell
# Select your vhdx file
select vdisk file="C:\Users\mioyi\AppData\Local\Docker\wsl\disk\docker_data.vhdx"

# Mount in read-only mode
attach vdisk readonly

# Compress the virtual disk (core operation, this step may take some time)
compact vdisk

# Detach and exit diskpart
detach vdisk
exit
```

After execution, you will find that the size of the `.vhdx` file has significantly decreased, close to the actual upper-layer read/write usage of your current Docker system. You can then reopen Docker Desktop and use it normally.

### Appendix: One-Click Cleanup Script

Usage: `.\Compact-Vhdx.ps1 C:\Users\mioyi\AppData\Local\Docker\wsl\disk\docker_data.vhdx`

```powershell {filename="Compact-Vhdx.ps1"}
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$VhdxPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    $ResolvedVhdxPath = (Resolve-Path -LiteralPath $VhdxPath).ProviderPath
} catch {
    Write-Error "VHDX file not found: $VhdxPath"
    exit 1
}

if (-not (Test-IsAdministrator)) {
    if (-not $PSCommandPath) {
        Write-Error 'This script must be saved as a .ps1 file before it can self-elevate.'
        exit 1
    }

    $powerShellExe = (Get-Process -Id $PID).Path
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        "`"$PSCommandPath`""
        '-VhdxPath'
        "`"$ResolvedVhdxPath`""
    )

    $process = Start-Process -FilePath $powerShellExe -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    exit $process.ExitCode
}

$diskpartScript = [IO.Path]::GetTempFileName()

try {
    $commands = @(
        "select vdisk file=`"$ResolvedVhdxPath`""
        'attach vdisk readonly'
        'compact vdisk'
        'detach vdisk'
        'exit'
    )

    Set-Content -LiteralPath $diskpartScript -Value $commands -Encoding ASCII

    Write-Host "Running diskpart compact for: $ResolvedVhdxPath"
    & diskpart.exe /s $diskpartScript

    if ($LASTEXITCODE -ne 0) {
        throw "diskpart failed with exit code $LASTEXITCODE."
    }
} finally {
    if (Test-Path -LiteralPath $diskpartScript) {
        Remove-Item -LiteralPath $diskpartScript -Force
    }
}
```
