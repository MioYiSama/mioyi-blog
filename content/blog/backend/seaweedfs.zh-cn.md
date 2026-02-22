---
title: SeaweedFS 最强攻略
tags: [后端]
---

> SeaweedFS官方Wiki写得很垃圾，因此研究了很多天才弄出解决方案

## Docker Compose 配置

> [!WARNING]
> volumeSizeLimitMB不要设置得太大，SeaweedFS会预分配volume空间，而且默认一个collection（对应一个s3 bucket）会至少创建7个volume，会迅速导致硬盘空间不足。

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

## S3配置文件

> [!NOTE]
>
> - `name`为用户名
> - `accessKey`、`secretKey`自由设置
> - `actions`为具体权限。参阅 <https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API#static-configuration>

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

## Caddy反向代理

同时支持VirtualHost Style和Path Style。

> [!WARNING]
> 上面s3服务一定要配置`domainName`，否则Virtual Host Style模式会签名错误

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
