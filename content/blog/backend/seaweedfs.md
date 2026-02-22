---
title: SeaweedFS Ultimate Guide
tags: [Backend]
---

> The official SeaweedFS Wiki is written terribly, so after many days of research I came up with a solution.

## Docker Compose Configuration

> [!WARNING]
> Do not set `volumeSizeLimitMB` too large; SeaweedFS will pre‑allocate volume space, and by default a single collection (corresponding to an S3 bucket) will create at least 7 volumes, which can quickly lead to insufficient disk space.

```yml {filename="docker-compose.yml"}
# https://github.com/seaweedfs/seaweedfs/blob/master/docker/seaweedfs-compose.yml
# https://github.com/seaweedfs/seaweedfs/wiki/Production-Setup
services:
  master:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-master
    restart: unless-stopped
    # -defaultReplication=000: https://github.com/seaweedfs/seaweedfs/wiki/Replication
    # -volumeSizeLimitMB=64: https://github.com/seaweedfs/seaweedfs/wiki/Production-Setup
    command: master -ip=seaweedfs-master -ip.bind=0.0.0.0 -defaultReplication=000 -volumeSizeLimitMB=64

    networks:
      - seaweedfs

    volumes:
      - master:/data

  volume:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-volume
    restart: unless-stopped
    # -index=leveldb: https://github.com/seaweedfs/seaweedfs/wiki/Optimization
    # -max=0: https://github.com/seaweedfs/seaweedfs/wiki/Production-Setup
    # https://github.com/seaweedfs/seaweedfs/wiki/S3-API-FAQ#can-not-upload-due-to-no-free-volumes-left
    command: volume -ip=seaweedfs-volume -ip.bind=0.0.0.0 -master="seaweedfs-master:9333" -index=leveldb -max=0
    depends_on:
      - master

    networks:
      - seaweedfs

    volumes:
      - volume:/data

  filer:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-filer
    restart: unless-stopped
    command: filer -ip=seaweedfs-filer -ip.bind=0.0.0.0 -master="seaweedfs-master:9333"
    tty: true
    stdin_open: true
    depends_on:
      - master
      - volume

    networks:
      - seaweedfs

    volumes:
      - filer:/data

  s3:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-s3
    restart: unless-stopped
    # https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API
    # https://github.com/seaweedfs/seaweedfs/wiki/S3-API-FAQ
    command: s3 -ip.bind=0.0.0.0 -filer="seaweedfs-filer:8888" -config=/s3.config.json -domainName="s3.mioyi.net"
    depends_on:
      - master
      - volume
      - filer

    networks:
      - seaweedfs

    # https://github.com/seaweedfs/seaweedfs/blob/master/docker/compose/s3.json
    volumes:
      - ./s3.config.json:/s3.config.json
      - s3:/data

networks:
  seaweedfs:
    name: seaweedfs

volumes:
  master:
    name: seaweedfs-master
  volume:
    name: seaweedfs-volume
  filer:
    name: seaweedfs-filer
  s3:
    name: seaweedfs-s3
```

## S3 Configuration File

> [!NOTE]
>
> - `name` is the username
> - `accessKey` and `secretKey` can be set freely
> - `actions` are the specific permissions. See <https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API#static-configuration>

```json {filename="s3.config.json"}
{
  "identities": [
    {
      "name": "anonymous",
      "actions": ["Read"]
    },
    {
      "name": "admin",
      "credentials": [
        {
          "accessKey": "███",
          "secretKey": "██████"
        }
      ],
      "actions": ["Admin", "Read", "Write", "List", "Tagging"]
    },
    {
      "name": "casdoor",
      "credentials": [
        {
          "accessKey": "███",
          "secretKey": "██████"
        }
      ],
      "actions": ["Read:casdoor", "Write:casdoor", "List:casdoor", "Tagging:casdoor"]
    }
  ]
}
```

## Caddy Reverse Proxy

Supports both VirtualHost Style and Path Style simultaneously.

> [!WARNING]
> The S3 service above must have `domainName` configured, otherwise Virtual Host Style mode will cause signature errors.

```caddyfile {filename="Caddyfile"}
*.mioyi.net {
	@s3 host s3.mioyi.net
	handle @s3 {
		reverse_proxy seaweedfs-s3:8333
	}
}

# https://github.com/seaweedfs/seaweedfs/wiki/S3-Nginx-Proxy
# https://github.com/seaweedfs/seaweedfs/wiki/S3-API-FAQ#s3-authentication-fails-when-using-reverse-proxy
*.s3.mioyi.net {
	reverse_proxy seaweedfs-s3:8333 {
		flush_interval -1

		# https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#defaults
		# https://caddyserver.com/docs/json/apps/http/#docs
		header_up X-Forwarded-Port {port}
		header_up -Connection
	}
}
```
