---
title: Caddy auto lang switch on first visit
tags: [backend]
weight: -2
---

Implemented a first‑visit automatic language switch for a blog using Caddy. The main issues are with matchers and cookies.

```caddyfile {filename="Caddyfile"}
*.mioyi.net {
	encode

	@www host www.mioyi.net
	handle @www {
		@al_zh header_regexp al Accept-Language (?i)\bzh(?:-cn)?\b
		@first_visit {
			not header_regexp Cookie (?i)first=0
		}
		handle @first_visit {
			header Set-Cookie "first=0; Path=/; Max-Age=31536000"
			redir @al_zh /zh-cn{query} 302
		}

		root * /blog
		file_server
	}
}
```
