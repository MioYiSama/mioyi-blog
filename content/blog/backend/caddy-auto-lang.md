---
title: Auto Website Language Switching with Caddy
tags: [backend]
---

I implemented an automatic language switching feature for my blog using Caddy. At first, I thought it would be simple, but I kept running into obstacles.

- It must determine whether it is the first visit; otherwise, if a user manually switches the language, Caddy cannot distinguish that type of request and will redirect indiscriminately.
- Then, it needs to check if the user's language matches the page language; if they match, no switching should occur.
- Switching must only apply to HTML files (`not path_regexp \.[a-zA-Z0-9]+$`); otherwise, requesting other types of files will result in "Too Many Redirects." Furthermore, Hugo's multilingual setup only generates HTML files and no other files.
- For English scenarios, the `/zh-cn` prefix needs to be removed.

```caddyfile {filename="Caddyfile"}
*.mioyi.net {
	encode

	@www host www.mioyi.net
	handle @www {
		# Whether it is the first visit
		@first_visit {
			not header_regexp Cookie (?i)first=0
		}
		# User is Chinese, page is English
		@to_zh {
			header_regexp al Accept-Language (?i)\bzh
			not path /zh-cn*
			not path_regexp \.[a-zA-Z0-9]+$
		}
		# User is English, page is Chinese
		@to_en {
			not header_regexp al Accept-Language (?i)\bzh
			path_regexp en_path ^/zh-cn(?:/)?(.*)$
			not path_regexp \.[a-zA-Z0-9]+$
		}

		# Automatic language switching
		route @first_visit {
			# Mark as not the first visit
			header Set-Cookie "first=0; Path=/; Max-Age=604800"
			# Switch to Chinese
			redir @to_zh /zh-cn{uri}
			# Switch to English
			redir @to_en /{re.en_path.1}
		}

		# Handle requests
		root * /var/www/blog
		file_server {
			precompressed zstd
		}
	}
}
```
