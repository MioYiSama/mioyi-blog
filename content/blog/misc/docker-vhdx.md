---
title: Shrink Docker WSL2 vhdx Disk Size
tags: [misc]
---

When using Docker Desktop with the WSL2 backend on Windows, the dynamic VHD disk (`docker_data.vhdx`) automatically grows as data is dumped. However, when you delete unused images or containers inside Docker, the host file does not shrink automatically. It is a common occurrence to see the `.vhdx` file bloated up to massive sizes like 130GB, even though the actual Docker usage is only a fraction of that.

## Core Solution: Directly Compact the VHDX

The most effective way to reclaim your host machine disk space is to use the Windows `diskpart` tool to manually compact the bloated virtual disk file. Simply running `docker system prune` is not enough to shrink the container file on the host side.

### 1. Clean up unused Docker data

Before compacting the disk, it's highly recommended to clean up any unwanted images, containers, and build caches to maximize the space savings:

```bash
# Check space usage
docker system df

# Remove all dangling resources, stopped containers, and unused volumes
docker system prune -a --volumes
```

### 2. Shut down WSL

Fully exit Docker Desktop. To safely release the VHDX file from its mounted state, run the following in an **Administrator PowerShell**:

```powershell
wsl --shutdown
```

### 3. Compact with Diskpart

While still in your Administrator PowerShell, open `diskpart` and run the following commands sequentially (replace the file path with your actual setup if different):

```powershell
# Select the path to your vhdx file
select vdisk file="C:\Users\mioyi\AppData\Local\Docker\wsl\disk\docker_data.vhdx"

# Attach as read-only
attach vdisk readonly

# Compact the virtual disk (This is the core action and might take some time)
compact vdisk

# Detach and exit
detach vdisk
exit
```

Once completed, the massive `.vhdx` file size will dramatically decrease, matching your actual internal Docker filesystem usage again! You can now restart Docker Desktop and resume your work.
