---
title: Caddy首次访问自动切换语言
tags: [后端]
weight: -2
---

用Caddy给博客做了一个首次访问自动切换语言的功能。主要就是matcher和Cookie的问题

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
