---
title: 玩弄服务器的一些心得
tags: [服务器]
weight: -1
---

## 服务器选择

- Cloud Provider：国外的基本得要信用卡，可以直接Pass。国内阿里云份额最大，但是对于普通人来说区别不大，可以看价格下菜，但是选冷门云厂商要慎重。
- CPU：至少两个核心，一个核心运维都难，服务和你的ssh抢饭吃。
- 内存：至少2GB，4GB是舒适区。如果没有Java服务还行，一旦有Java就洗洗睡吧。内存少的服务器只能用go和rust，jvm和node的服务完全用不了。只要自己亲自部署过服务的就知道go有多香了，jvm根本不敢用。
- 网络：不怕DDoS可以选择流量计费，否则还是带宽吧。（我目前选的是流量）
- 地域：目前来看香港还是最优解，不仅不用备案，还能直接docker pull镜像、git clone等等，甚至还能搞proxy。

## 操作系统选择

服务器端不是Debian系就是RHEL系。免费的里面Debian和AlmaLinux最为突出（RockyLinux的作者风评不好）。喜欢RHEL（保守派）的选AlmaLinux，但是dnf管理器更新软件包比apt慢得多，有时候还要看红帽脸色。Debian在生态和轻量上更有优势，Docker都选择了debian作为hardened image。

> （实际上CentOS Stream不是不能用，只是给人们带来的心理落差太大了，就看起来很危险。它甚至还能比RHEL更早拿到安全补丁，而且上游还有Fedora兜底）

## 准备工作

### ssh

不建议用密码，建议用密钥。sshd_config里启用公钥登录，还可以顺带禁用密码登录。
。
最佳的公私钥算法是ed25519，因此可以用`ssh-keygen -t ed25519`生成。剩下的操作就略过了，教程极其多。

### Docker

Docker的优点不只是reproducible。服务的配置文件、生命周期、网络（端口）、日志、更新、CVE等等全都可以由Docker包办。

安装方式官方文档写得很详细：<https://docs.docker.com/engine/install/>

如果默认不是root用户，可以考虑把普通用户加入docker组（操作略，自己搜教程）

### 使用docker

不管是一个服务还是多个服务，建议全都使用Docker Compose配置。命令行的局限性太大。可以专门搞文件夹整理配置文件：

{{< filetree/container >}}
{{< filetree/folder name="docker" >}}

{{< filetree/folder name="caddy2" >}}
{{< filetree/folder name="conf" >}}
{{< filetree/file name="Caddyfile" >}}
{{< /filetree/folder >}}
{{< filetree/file name="docker-compose.yml" >}}
{{< filetree/file name="Dockerfile" >}}
{{< filetree/file name=".env" >}}
{{< filetree/file name="reload.sh" >}}
{{< /filetree/folder >}}

{{< filetree/folder name="casdoor" >}}
{{< filetree/folder name="conf" >}}
{{< filetree/file name="app.conf" >}}
{{< /filetree/folder >}}
{{< filetree/file name="docker-compose.yml" >}}
{{< /filetree/folder >}}

{{< filetree/folder name="postgres18" >}}
{{< filetree/file name="docker-compose.yml" >}}
{{< filetree/file name=".env" >}}
{{< /filetree/folder >}}

{{< filetree/folder name="seaweedfs" >}}
{{< filetree/file name="docker-compose.yml" >}}
{{< filetree/file name="s3.config.json" >}}
{{< /filetree/folder >}}

{{< /filetree/folder >}}
{{< /filetree/container >}}

具体配置举例：

- 能写清楚major版本号的写清楚，便于无缝更新；不能的先看看有没有stable等版本，最后选择latest。后续不要轻易更新服务，不然很可能导致服务崩溃，甚至产生连锁反应，因此我没有写 `pull_policy: always`。严格遵循SemVer的可以大胆更新。
- 建议使用env file，不要直接把环境变量写在compose文件里
- 配置文件统一用本地目录挂载；否则尽量使用docker的volume管理。（本地目录其实是可以直接访问到volume里的文件的）
- 尽可能使用桥接网络+docker自带的ip解析功能（容器名自动解析为具体ip）。生产者创建一个独立的桥接网络，消费者加入生产者的网络后使用容器名访问。除了反向代理服务之外尽可能避免暴露端口到宿主机。

```yml {filename="docker-compose.yml"}
services:
  caddy2:
    build: .
    image: caddy2-custom

    container_name: caddy2
    restart: unless-stopped
    env_file: .env

    cap_add:
      - NET_ADMIN
    networks:
      - postgres18
      - seaweedfs
      - casdoor
      - openlist
      - memos
    ports:
      - 80:80
      - 443:443
      - 443:443/udp
      - 5432:5432

    volumes:
      - ./conf:/etc/caddy
      - ./static:/static
      - data:/data
      - config:/config

networks:
  postgres18:
    external: true
  seaweedfs:
    external: true
  casdoor:
    external: true
  openlist:
    external: true
  memos:
    external: true

volumes:
  data:
    name: caddy2-data
  config:
    name: caddy2-config
```

## 基础服务选择

最主要的基础服务就是反向代理（外界访问）、数据库（存数据）、对象存储（帮助数据库存文件）、身份认证（不必多言）。

### 反向代理

很多人第一反应肯定是Nginx，非常老牌的web服务器。但是在caddy面前Nginx的DX（Developer Experience）就太糟糕了。Traefik、HAProxy等反向代理过于高级，只适合极端性能的场景使用；Kong等网关类产品不适合个人服务器使用。

Caddy使用插件需要独立构建一个caddy执行文件：

```dockerfile {filename="Dockerfile"}
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddy-dns/alidns

FROM caddy:2-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

Caddyfile举例：

```caddyfile {filename="Caddyfile"}
{
	acme_dns alidns { # 自动用阿里云DNS配置https
		access_key_id {env.ALIYUN_ACCESS_KEY_ID}
		access_key_secret {env.ALIYUN_ACCESS_KEY_SECRET}
	}

	layer4 { # TCP代理数据库连接，统一用caddy更安全
		:5432 {
			route {
				proxy postgres18:5432
			}
		}
	}
}

mioyi.net { # 自动跳转到www
	redir https://www.mioyi.net
}

*.mioyi.net {
	encode # 自动zstd, gzip压缩

	@www host www.mioyi.net
	handle @www {
		reverse_proxy memos:8080 # 反向代理
	}

	@static host static.mioyi.net
	handle @static { # 静态文件托管
		root * /static
		file_server browse
	}

	@s3 host s3.mioyi.net
	handle @s3 {
		reverse_proxy seaweedfs-s3:8333
	}

	@auth host auth.mioyi.net
	handle @auth {
		reverse_proxy casdoor:8000
	}

	@oplist host oplist.mioyi.net
	handle @oplist {
		reverse_proxy openlist:5244
	}
}

*.s3.mioyi.net {
	encode

	rewrite * /{http.request.host.labels.3}{uri} # 自动重写Virtual Host风格的链接

	reverse_proxy seaweedfs-s3:8333 {
		flush_interval -1
	}
}
```

### 数据库

PostgreSQL是开源数据库里的佼佼者，无须多言。

创建用户+数据库教程：

```sql
create user casdoor with password '123456';
create database casdoor with owner casdoor;
```

### 对象存储

自从MinIO作恶之后，好用的对象存储似乎就没了。目前社区关注比较高的是：

- GarageHQ：只支持CLI管理；当下版本还不支持anonymous的文件访问。
- SeaweedFS：分布式存储，但是既支持anonymous访问也支持细粒度的鉴权。Docker Hardened Image中唯一的对象存储，足够可信。
- RustFS：新星，使用体验不错，但是有很多负面评价，成熟度不够
- Ceph：分布式存储。（我暂未尝试过）

目前我的选择是SeaweedFS，除了部署稍微麻烦一点全是优点。

DockerCompose配置文件：

> WebDAV是可选项，可以套一个OpenList（AList后继）作为前端管理文件

```yml {filename="docker-compose.yml"}
# https://github.com/seaweedfs/seaweedfs/wiki/Production-Setup
# https://github.com/seaweedfs/seaweedfs/blob/master/docker/seaweedfs-compose.yml
services:
  master:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-master
    restart: unless-stopped
    command: master -ip=seaweedfs-master -ip.bind=0.0.0.0 -defaultReplication=000 -volumeSizeLimitMB=1024

    networks:
      - seaweedfs

    volumes:
      - master:/data

  volume:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-volume
    restart: unless-stopped
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
    command: s3 -ip.bind=0.0.0.0 -filer="seaweedfs-filer:8888" -config=/s3.config.json
    depends_on:
      - master
      - volume
      - filer

    networks:
      - seaweedfs

    # https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API
    # https://github.com/seaweedfs/seaweedfs/blob/master/docker/compose/s3.json
    volumes:
      - ./s3.config.json:/s3.config.json
      - s3:/data

  webdav:
    image: chrislusf/seaweedfs:latest

    container_name: seaweedfs-webdav
    restart: unless-stopped
    command: webdav -filer="seaweedfs-filer:8888"
    depends_on:
      - master
      - volume
      - filer

    networks:
      - seaweedfs

    volumes:
      - webdav:/data

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
  webdav:
    name: seaweedfs-webdav
```

S3配置文件：

> 既可以配置anonymous权限，也支持细分到具体操作和Bucket的权限。

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
    },
    {
      "name": "memos",
      "credentials": [
        {
          "accessKey": "███",
          "secretKey": "██████"
        }
      ],
      "actions": ["Read:memos", "Write:memos", "List:memos", "Tagging:memos"]
    }
  ]
}
```

### 身份认证

casdoor的UX（User Experience）非常好（至少比Keycloak和Authentik好），也有中文支持。配置单点登录后可以自动登录你部署的所有App。具体配置篇幅较大，略。
