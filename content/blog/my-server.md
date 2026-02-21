---
title: Some Tips for Playing with Servers
tags: [server]
weight: -1
---

---

## Server Selection

- **Cloud Provider**: Overseas providers generally require a credit card, which you can pass easily. Domestically, Alibaba Cloud has the biggest market share, but for regular users the difference isn’t huge; you can compare prices and pick a cheaper option, but be cautious when choosing lesser‑known cloud vendors.
- **CPU**: At least two cores; a single core makes operations difficult, and the service will compete with your SSH for resources.
- **Memory**: Minimum 2 GB, 4 GB is the comfortable zone. It's okay if you don’t run Java services; once you do, you’re in trouble. Low‑memory servers should stick to Go or Rust; JVM and Node.js services just won’t run. Anyone who’s deployed a service themselves knows how pleasant Go is, and you’d never dare use the JVM on such a box.
- **Network**: If you’re not worried about DDoS, you can go with traffic‑based billing; otherwise stick with bandwidth. (I’m currently using traffic.)
- **Region**: Currently Hong Kong is the best choice—it doesn’t require ICP filing, you can docker pull images, git clone, etc., and you can even set up a proxy.

## Operating System Selection

Server OSes are usually either Debian‑based or RHEL‑based. Among the free options, Debian and AlmaLinux stand out (RockyLinux’s author has a poor reputation). If you like RHEL (conservative), pick AlmaLinux, but the `dnf` package manager updates much slower than `apt`, and you sometimes have to watch Red Hat’s mood. Debian has advantages in ecosystem and lightweight nature; Docker even uses Debian as its hardened image.

> (In reality, CentOS Stream isn’t unusable; it just gives a strong psychological impression of being risky. It can even receive security patches earlier than RHEL, with Fedora as the upstream safety net.)

## Preparation

### ssh

Avoid passwords; use SSH keys. Enable public‑key authentication in `sshd_config` and you can also disable password login.

The preferred key algorithm is **ed25519**, so run `ssh-keygen -t ed25519` to generate one. The rest is straightforward; there are plenty of tutorials.

### Docker

Docker’s benefits are more than just reproducibility. Service configuration files, lifecycle, networking (ports), logs, updates, CVEs, etc., can all be handled by Docker.

Installation instructions are detailed in the official docs: <https://docs.docker.com/engine/install/>

If you don’t run as root by default, consider adding your regular user to the `docker` group (steps omitted; look up a tutorial).

### Using Docker

Whether you have a single service or many, it’s recommended to configure everything with Docker Compose. The CLI’s limitations are too great. You can organize configuration files in dedicated folders:

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

Specific configuration tips:

- If you can specify a clear major version, do so to enable seamless upgrades; if not, look for a `stable` tag or fall back to `latest`. Don’t update services lightly later on, as it can cause crashes or chain reactions, which is why I didn’t add `pull_policy: always`. Projects that strictly follow SemVer can be updated more boldly.
- Prefer using an `.env` file instead of embedding environment variables directly in the compose file.
- Mount configuration files via local directories; otherwise use Docker volumes (local directories can actually access the files inside a volume).
- Use bridge networks together with Docker’s built‑in name resolution (container names resolve to IPs automatically). Have the producer create an isolated bridge network, and let consumers join that network and refer to services by container name. Apart from reverse‑proxy services, avoid exposing ports to the host as much as possible.

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

## Core Service Selection

The essential core services are reverse proxy (external access), database (data storage), object storage (helps the database store files), and authentication (self‑explanatory).

### Reverse Proxy

Many people’s first instinct is Nginx, a classic web server. But compared to Caddy, Nginx’s developer experience is poor. Traefik, HAProxy, etc., are over‑engineered and only suited for extreme performance scenarios; gateway‑type products like Kong aren’t a good fit for personal servers.

Caddy requires building a custom binary when you need plugins:

```dockerfile {filename="Dockerfile"}
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-l4 \
    --with github.com/caddy-dns/alidns

FROM caddy:2-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

Example `Caddyfile`:

```caddyfile {filename="Caddyfile"}
{
	acme_dns alidns { # automatically obtain HTTPS via Alibaba Cloud DNS
		access_key_id {env.ALIYUN_ACCESS_KEY_ID}
		access_key_secret {env.ALIYUN_ACCESS_KEY_SECRET}
	}

	layer4 { # TCP proxy for database connections; using Caddy makes it safer
		:5432 {
			route {
				proxy postgres18:5432
			}
		}
	}
}

mioyi.net { # redirect to www
	redir https://www.mioyi.net
}

*.mioyi.net {
	encode # automatic zstd, gzip compression

	@www host www.mioyi.net
	handle @www {
		reverse_proxy memos:8080 # reverse proxy
	}

	@static host static.mioyi.net
	handle @static { # static file hosting
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

	rewrite * /{http.request.host.labels.3}{uri} # auto‑rewrite Virtual‑Host style links

	reverse_proxy seaweedfs-s3:8333 {
		flush_interval -1
	}
}
```

### Database

PostgreSQL is a top‑tier open‑source database—no further explanation needed.

Create user + database:

```sql
create user casdoor with password '123456';
create database casdoor with owner casdoor;
```

### Object Storage

Since the MinIO controversy, good object‑storage options have been scarce. Currently the community’s most discussed solutions are:

- **GarageHQ**: CLI‑only management; current version doesn’t support anonymous file access.
- **SeaweedFS**: Distributed storage that supports both anonymous access and fine‑grained authentication. It’s the only object storage with a hardened Docker image, and it’s trustworthy.
- **RustFS**: A newcomer with a decent user experience but many negative reviews; maturity is lacking.
- **Ceph**: Distributed storage (I haven’t tried it yet).

My choice is SeaweedFS—aside from a slightly more involved deployment, it’s all positives.

Docker‑Compose configuration (WebDAV is optional; you can layer an OpenList (successor to AList) as a frontend for file management):

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

S3 configuration file (can define anonymous permissions and also fine‑grained actions per bucket):

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

### Authentication

Casdoor offers an excellent user experience (at least better than Keycloak and Authentik) and includes Chinese support. After configuring single sign‑on, you can automatically log into all the apps you’ve deployed. The detailed configuration is extensive, so it’s omitted here.
