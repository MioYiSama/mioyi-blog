---
title: Some Insights into Playing with Servers
tags: [Server]
weight: -1
---

## Server Selection

- Cloud Vendors: Foreign vendors basically require a credit card, so you can pass them by. In China, Alibaba Cloud has the largest market share, but for ordinary individuals, the difference between various major cloud services is negligible. You can choose based on price, but be cautious with smaller vendors.
- CPU: At least two cores. Managing a server with one core is difficult, as services will compete with your SSH and VSCode Server for resources.
- RAM: At least 2GB; 4GB is the comfort zone. It's manageable if you don't have Java services, but once Java is involved, forget about it. Servers with low memory can only run Go and Rust; JVM and Node services are completely out of the question. Anyone who has personally deployed services knows how great Go is; I wouldn't dare use JVM.
- Network: If you are sure your traffic won't be high or you aren't afraid of DDoS, you can choose pay-by-traffic; otherwise, choose fixed bandwidth.
- Region: Currently, Hong Kong is the optimal choice. Not only does it not require ICP filing, but accessing Docker Hub, GitHub, Hugging Face, etc., does not require a proxy, and you can even set up a proxy server.

## OS Selection

Server-side is either Debian-based or RHEL-based.

Among the free options, Debian and AlmaLinux are the most prominent (the reputation of RockyLinux's author is not great). Choose AlmaLinux if you like RHEL (the conservative camp), but the `dnf` manager updates packages much slower than `apt`, and sometimes package updates depend on Red Hat's schedule. Debian has a clear advantage in the ecosystem; Docker even chose Debian as the basis for its Docker Hardened Image.

> \[!NOTE]
> Actually, CentOS Stream isn't unusable; it's just that the psychological gap it brought to people was too large, making it feel "dangerous." If you don't have an extreme obsession with security, worrying about this is less productive than worrying about whether other security measures are in place. In reality, it may even receive security patches earlier than RHEL, with Fedora serving as the upstream safety net.

## Preparation

### SSH

It is not recommended to use passwords; use keys instead. Enable public key login in `sshd_config` and you can also disable password login while you're at it.

The best public/private key algorithm is `ed25519` (generated via `ssh-keygen -t ed25519`). The rest of the steps are omitted as tutorials are extremely abundant.

### Docker

The advantage of Docker isn't just that it's reproducible. Service configuration files, life cycles, networks (ports), logs, updates, CVEs, etc., can all be handled by Docker.

The official documentation explains the installation method in detail: <https://docs.docker.com/engine/install/>

If the default user is not root, consider adding the regular user to the `docker` group.

### Using Docker

Whether it's one service or multiple, it's recommended to use Docker Compose for all configurations. The command line is too limited; configuration files are easier to maintain.

You can organize your configuration files in a dedicated folder like I do:

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

- Specify major version numbers clearly to facilitate seamless updates; if not possible, check for versions like `stable`, and choose `latest` as a last resort. Do not update services lightly later, as it might cause the service to crash (upgrading underlying services can cause a chain reaction, crashing other services). Thus, I didn't write `pull_policy: always`. For those strictly following SemVer, you can update boldly.
- It is recommended to use `.env` files rather than writing environment variables directly in the compose file.
- Use local directory mounts for configuration files globally; otherwise, try to use Docker's volume management. You can check the actual storage path on the host via `docker volume inspect <id>`.
- Use bridge networks and Docker's built-in IP resolution (container names automatically resolve to specific IPs) as much as possible. While host mode is convenient, container ports can easily conflict, and it's dangerous if the firewall is misconfigured. Create an independent bridge network for producers; consumers join the producer's network and access them via container names. Therefore, avoid exposing ports to the host machine as much as possible, except for the reverse proxy service.

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

## Selection of Infrastructure Services

The main infrastructure services are reverse proxy (external access), database (data storage), object storage (helping the database store files), and identity authentication (self-explanatory).

### Reverse Proxy

Many people's first thought is Nginx, a very established web server. However, compared to Caddy, Nginx's DX (Developer Experience) is too poor. Reverse proxies like Traefik and HAProxy are too advanced and suitable only for extreme performance scenarios; gateway products like Kong are not suitable for personal servers.

Using Caddy plugins requires building a custom Caddy executable:

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
	acme_dns alidns { # Automatically configure HTTPS using Alibaba Cloud DNS
		access_key_id {env.ALIYUN_ACCESS_KEY_ID}
		access_key_secret {env.ALIYUN_ACCESS_KEY_SECRET}
	}

	layer4 { # TCP proxy for database connections; using Caddy is more secure
		:5432 {
			route {
				proxy postgres18:5432
			}
		}
	}
}

mioyi.net { # Auto redirect to www
	redir https://www.mioyi.net
}

*.mioyi.net {
	encode # Auto zstd, gzip compression

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

	rewrite * /{http.request.host.labels.3}{uri} # Auto rewrite Virtual Host style links

	reverse_proxy seaweedfs-s3:8333 {
		flush_interval -1
	}
}
```

### Database

PostgreSQL is the leader among open-source databases; it goes without saying.

Tutorial for creating users + databases:

```sql
create user casdoor with password '123456';
create database casdoor with owner casdoor;
```

### Object Storage

Since MinIO turned "evil," convenient object storage seems to have disappeared. Currently, the ones with high community attention are:

- GarageHQ: Only supports CLI management; the current version does not support anonymous file access.
- SeaweedFS: Distributed storage, but supports both anonymous access and fine-grained authentication. The only object storage among Docker Hardened Images, it is trustworthy enough.
- RustFS: A rising star with a good user experience, but has many negative reviews and lacks maturity.
- Ceph: Distributed storage. (I haven't tried it yet)

My current choice is SeaweedFS. DockerCompose configuration file:

> \[!NOTE]
> WebDAV is optional; you can wrap it with OpenList (the successor to AList) as a frontend for managing files.

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

S3 configuration file:

> \[!NOTE]
> It allows configuring anonymous permissions and also supports fine-grained permissions for specific operations and Buckets.

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

> \[!NOTE]
> SeaweedFS is mainly designed for distributed storage + a massive amount of small files, so it is very aggressive in volume creation, creating a lot of concurrent writes and disaster recovery replicas. This is very tight for personal servers with small hard drives. Configuring it with `-defaultReplication=000 -volumeSizeLimitMB=1024` can solve the space crunch to some extent. However, don't create too many buckets, because one bucket corresponds to one collection, and SeaweedFS will pre-allocate capacity.

### Identity Authentication

Casdoor's UX (User Experience) is very good (at least better than Keycloak and Authentik), and it also has Chinese support. After configuring Single Sign-On (SSO), you can automatically log in to all the apps you deploy. The specific configuration is quite extensive, so it is omitted here.
