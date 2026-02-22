---
title: Some Insights on Tinkering with Servers
tags: [Backend]
---

## Server Selection

- Cloud providers: Foreign ones basically require a credit card, so you can pass on them directly. Domestically, Alibaba Cloud has the largest market share, but the differences between major cloud providers' services are negligible for ordinary people. You can choose based on price, but be cautious when choosing small providers.
- CPU: At least two cores. Operation and maintenance are hard with just one core, as your services will fight for resources with your ssh and vscode server.
- Memory: At least 2GB; 4GB is the comfort zone. It's fine if there are no Java services, but once you have Java, just forget about it. Servers with little memory can only run go and rust; jvm and node services are completely unusable. Anyone who has manually deployed services knows how sweet go is, and wouldn't dare to use jvm.
- Network: If you are sure the traffic will be low or if you are not afraid of DDoS, you can choose pay-by-traffic; otherwise, choose fixed bandwidth.
- Region: Currently, Hong Kong is still the optimal solution. Not only is ICP registration not required, but accessing Docker Hub, GitHub, Huggingface, etc., doesn't require a proxy, and you can even set up a proxy server.

## Operating System Selection

Server sides are typically either Debian-based or RHEL-based.

Among the free ones, Debian and AlmaLinux stand out the most (the author of RockyLinux has a bad reputation). Those who like RHEL (conservatives) should choose AlmaLinux, but the dnf package manager updates packages much slower than apt, and sometimes package updates are at the mercy of Red Hat. Debian has an extremely obvious advantage in ecology; even Docker chose debian for its Docker Hardened Image.

> [!NOTE]
> Actually, CentOS Stream is not unusable, it's just that the psychological gap it brought to people is too big, making it feel very dangerous. If you are not a strict perfectionist about security, rather than worrying about this, you should worry about whether security measures elsewhere are done well. In fact, it can sometimes get security patches even earlier than RHEL, and it is backed by Fedora upstream.

## Preparation Work

### ssh

Using passwords is not recommended; it's recommended to use keys. Enable public key login in sshd_config, and you can conveniently disable password login while you are at it.

The best public-private key algorithm is ed25519 (can be generated using `ssh-keygen -t ed25519`). I will skip the rest of the operations, as there are extremely many tutorials available.

### Docker

Docker's advantages are not just being reproducible. Service configuration files, lifecycles, networks (ports), logs, updates, CVEs, etc., can all be handled entirely by Docker.

The installation method is detailed in the official documentation: <https://docs.docker.com/engine/install/>

If you are not the root user by default, consider adding your regular user to the docker group.

### Using Docker

Whether it is a single service or multiple services, it is recommended to configure them all using Docker Compose. The limitations of the command line are too great; configuration files are easier to maintain.

You can be like me and specifically create a folder to organize configuration files:

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

Specific configuration examples:

- Write down the major version number clearly if possible, to facilitate seamless updates; if not, first check if there are versions like stable, and finally choose latest. Do not update services lightly afterwards, otherwise it is very likely to cause service crashes (if upgrading underlying services, it will also cause a chain reaction, crashing other services). Therefore, I did not write `pull_policy: always`. Those strictly following SemVer can update boldly.
- It is recommended to use `.env` and not write environment variables directly in the compose file.
- Configuration files should be uniformly mounted using local directories; otherwise, try to use Docker's volume management. You can check the actual storage path on the host machine via `docker volume inspect <id>`.
- Use bridge networks and Docker's built-in IP resolution function (container names are automatically resolved to specific IPs) as much as possible. Although host mode is very convenient, container ports are very prone to conflicts, and it is very dangerous if the firewall is configured improperly. The producer creates an independent bridge network, and after consumers join the producer's network, they access it using the container name. Therefore, except for reverse proxy services, avoid exposing ports to the host machine as much as possible.

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

## Basic Service Selection

The most essential basic services are reverse proxy (external access), database (storing data), object storage (assisting the database in storing files), and identity authentication (needless to say).

### Reverse Proxy

Many people's first reaction is definitely Nginx, a very well-established web server. However, in front of Caddy, Nginx's DX (Developer Experience) is just too terrible. Reverse proxies like Traefik and HAProxy are too advanced and only suitable for extreme performance scenarios; gateway products like Kong are not suitable for personal server use.

Using plugins with Caddy requires building a standalone Caddy executable file:

```dockerfile {filename="Dockerfile"}
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddy-dns/alidns

FROM caddy:2-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

Caddyfile example:

```caddyfile {filename="Caddyfile"}
{
	acme_dns alidns { # Automatically configure HTTPS with Alibaba Cloud DNS
		access_key_id {env.ALIYUN_ACCESS_KEY_ID}
		access_key_secret {env.ALIYUN_ACCESS_KEY_SECRET}
	}

	layer4 { # TCP proxy for database connections; using Caddy uniformly is safer
		:5432 {
			route {
				proxy postgres18:5432
			}
		}
	}
}

mioyi.net { # Automatically redirect to www
	redir https://www.mioyi.net
}

*.mioyi.net {
	encode # Automatic zstd, gzip compression

	@www host www.mioyi.net
	handle @www {
		reverse_proxy memos:8080 # Reverse proxy
	}

	@static host static.mioyi.net
	handle @static { # Static file hosting
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

	rewrite * /{http.request.host.labels.3}{uri} # Automatically rewrite Virtual Host style links

	reverse_proxy seaweedfs-s3:8333 {
		flush_interval -1
	}
}
```

### Database

PostgreSQL is an outstanding leader among open-source databases; needless to say more.

User + database creation tutorial:

```sql
create user casdoor with password '123456';
create database casdoor with owner casdoor;
```

### Object Storage

Since MinIO turned evil, it seems there are no easy-to-use object storages left. Currently, the ones with relatively high community attention are:

- GarageHQ: Only supports CLI management; the current version does not yet support anonymous file access.
- SeaweedFS: Distributed storage, but it supports both anonymous access and fine-grained authentication. The only object storage in the Docker Hardened Image, trustworthy enough.
- RustFS: A rising star, good user experience, but has many negative reviews and insufficient maturity.
- Ceph: Distributed storage. (I haven't tried it yet).

My current choice is SeaweedFS. DockerCompose configuration file:

> [!NOTE]
> WebDAV is an option; you can wrap an OpenList (AList successor) as a front-end to manage files.

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

S3 configuration file:

> [!NOTE]
> You can configure anonymous permissions, and it also supports granular permissions down to specific operations and Buckets.

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

Caddy proxying S3 API (supports Virtual Host Style)

> [!NOTE]
> DNS requires configuring wildcard domain resolution for \*.s3.mioyi.net; just \*.mioyi.net is not enough.

```caddyfile {filename="Caddyfile"}
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

> [!NOTE]
> SeaweedFS is primarily designed for distributed + massive small file storage, so it is very aggressive in volume creation. It will create a large number of concurrent writes and disaster recovery replicas, and will also pre-allocate, which is very tight for personal servers with small hard drives. Therefore, the master must be configured with `-defaultReplication=000 -volumeSizeLimitMB=64`, and simultaneously the volume container must also be configured with `-max=0` to allow it to automatically scale without limits.
>
> See <https://github.com/seaweedfs/seaweedfs/wiki/Replication> <https://github.com/seaweedfs/seaweedfs/wiki/Optimization>

### Identity Authentication

Casdoor's UX (User Experience) is very good (at least better than Keycloak and Authentik), and it also has Chinese support. After configuring single sign-on, you can automatically log into all the Apps you deploy. Specific configurations are quite lengthy, so they are omitted here.
