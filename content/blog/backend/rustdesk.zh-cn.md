---
title: 自部署 RustDesk 服务
tags: [后端]
---

## Docker compose:

```yaml
services:
  hbbs:
    container_name: hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs
    volumes:
      - ./data:/root
    network_mode: "host"

    depends_on:
      - hbbr
    restart: unless-stopped

  hbbr:
    container_name: hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr
    volumes:
      - ./data:/root
    network_mode: "host"
    restart: unless-stopped
```

## 防火墙

- TCP 21115/21118
- UCP 21116

## 本地

Clash

```yaml
rules:
  - IP-CIDR,服务器IP/32,DIRECT
```
