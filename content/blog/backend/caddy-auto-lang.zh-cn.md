---
title: Caddy自动切换网站语言
tags: [后端]
---

用Caddy给博客做了一个自动切换语言的功能。一开始以为很简单，但是不断碰壁。

- 必须判断是不是首次访问，否则如果用户手动切换语言，Caddy无法区分这种类型的要求，会无差别跳转
- 然后得判断用户语言和网页语言对上了没，对上了就不要切换了
- 必须只对html文件进行切换（`not path_regexp \.[a-zA-Z0-9]+$`），否则请求其他类型的文件会出现Too Many Redirects，而且Hugo的多语言只生成html文件，不生成其他文件
- 对于英文场景，需要去除`/zh-cn`的前缀

```caddyfile {filename="Caddyfile"}
*.mioyi.net {
	encode

	@www host www.mioyi.net
	handle @www {
		# 是否首次访问
		@first_visit {
			not header_regexp Cookie (?i)first=0
		}
		# 用户中文，网页英文
		@to_zh {
			header_regexp al Accept-Language (?i)\bzh
			not path /zh-cn*
			not path_regexp \.[a-zA-Z0-9]+$
		}
		# 用户英文，网页中文
		@to_en {
			not header_regexp al Accept-Language (?i)\bzh
			path_regexp en_path ^/zh-cn(?:/)?(.*)$
			not path_regexp \.[a-zA-Z0-9]+$
		}

		# 自动切换语言
		route @first_visit {
			# 标记非首次访问
			header Set-Cookie "first=0; Path=/; Max-Age=604800"
			# 切换到中文
			redir @to_zh /zh-cn{uri}
			# 切换到英文
			redir @to_en /{re.en_path.1}
		}

		# 处理请求
		root * /var/www/blog
		file_server {
			precompressed zstd
		}
	}
}
```
