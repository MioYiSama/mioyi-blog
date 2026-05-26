---
title: 解决 WSL2 下 Docker vhdx 磁盘占用过大
tags: [杂项]
---

> 也可用于清理普通WSL发行版的文件

在 Windows 下使用 WSL2 后端运行 Docker Desktop 时，由于动态 VHD 磁盘（`docker_data.vhdx`）的特性，即使我们在 Docker 中删除了大量的无用镜像和容器，宿主机的磁盘空间并不会自动释放。很多时候容器实际占用只有 20 多 G，但宿主机的 `.vhdx` 文件却可能膨胀到 130G，甚至把 C 盘挤占满。

## 核心解决方案：直接压缩这个 VHDX

解决这个问题的最根本做法是先关机、然后利用 Windows 的 `diskpart` 工具手动压缩那个膨胀的虚拟磁盘文件。单纯执行 `docker system prune` 是不够的，必须真正把 VHD 文件压回去。

### 1. 清理 Docker 内部垃圾 (可选)

在压缩磁盘之前，最好先把不需要的镜像、僵尸容器彻底抛弃，腾出容器内部空间：

```bash
# 查看空间占用
docker system df

# 清理所有悬空资源、停止的容器和无用的缓存卷
docker system prune -a --volumes
```

### 2. 关闭 WSL

清理完毕后，彻底退出 Docker Desktop。为了让 WSL 的 VHDX 脱离挂载使用状态，在 **管理员权限的 PowerShell** 中运行：

```powershell
wsl --shutdown
```

### 3. 压缩磁盘

继续在管理员 PowerShell 中输入 `diskpart` 进入交互界面，接着依次执行以下命令（需要替换为你本地 `.vhdx` 的实际路径）：

```powershell
# 选择你的 vhdx 文件
select vdisk file="C:\Users\mioyi\AppData\Local\Docker\wsl\disk\docker_data.vhdx"

# 以只读模式挂载
attach vdisk readonly

# 压缩虚拟磁盘（核心操作，该步骤可能需要一点时间）
compact vdisk

# 卸载并退出 diskpart
detach vdisk
exit
```

执行完毕后，你会发现这块 `.vhdx` 文件的体积已经明显下降，接近于你现在系统 docker 的实际上层读写占用。之后可以重新打开 Docker Desktop 正常使用了。

### 附：一键清理脚本

使用方式：`.\Compact-Vhdx.ps1 C:\Users\mioyi\AppData\Local\Docker\wsl\disk\docker_data.vhdx`

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
