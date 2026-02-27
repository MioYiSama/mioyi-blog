---
title: "Rust使用体验"
tags: [编程语言]
---

# 优点

- 错误处理比Go还要再上一个台阶，更加健壮。一个服务越健壮越省心。
  - 错误声明（非常直观）

  ```rust
  #[derive(Debug, thiserror::Error)]
  pub enum InfoFetchError {
      #[error("发送HTTP请求失败: {0}")]
      SendHttpRequestError(reqwest::Error),
      #[error("HTTP响应错误: {0}")]
      HttpResponseError(reqwest::Error),
      #[error("HTTP响应体错误: {0}")]
      HttpResponseBodyError(reqwest::Error),
      #[error("未找到script元素")]
      NoScriptError,
      #[error("处理script错误")]
      ProcessScriptError,
      #[error("JSON解析错误: {0}")]
      JsonParseError(#[from] serde_json::Error),
      #[error("无PlayItem")]
      NoPlayItemError,
  }
  ```

  - 错误处理（非常健壮，强制检查错误）

  ```rust
  let resp = req
    .send()
    .await
    .map_err(|e| InfoFetchError::SendHttpRequestError(e))?
    .error_for_status()
    .map_err(|e| InfoFetchError::HttpResponseError(e))?;
  let text = resp
    .text()
    .await
    .map_err(|e| InfoFetchError::HttpResponseBodyError(e))?;
  ```

- 模式匹配虽然有一点门槛，但会用后非常强大

  ```rust
  // 进程守卫
  let token = CancellationToken::new();
  let t = token.clone();
  tokio::spawn(async move {
      match t.run_until_cancelled(process.wait()).await {
          // ffmpeg进程结束
          Some(Ok(_)) => t.cancel(),
          // 操作系统wait失败
          Some(Err(_)) => t.cancel(),
          // token取消
          None => {
              if let Err(_) = process.kill().await {
                  return;
              }
          }
      }
  });
  ```

- 联合类型很强大，可以轻松表达出“或”的语义，且0成本抽象

  ```rust
  #[derive(Debug)]
  pub enum Info {
    Offline,
    Online {
        id: String,
        streamer_name: String,
        hls_url: String,
        flv_urls: Vec<FlvUrl>,
    },
  }
  ```

- trait系统很强，搭配上泛型之后可以表达很多复杂语义，还可以为其他模块的结构体添加功能

- 模块比C++好用的多，同一个文件内还不用遵循使用的前后顺序，编译器也会自动检查循环引用

- 编译器很强，能检查出很多错误

- 集合、迭代器API完整

  ```rust
  let overlap = self
      .danmakus
      .iter()
      .position(|dm| dm == first)
      .map(|i| self.danmakus.len() - i)
      .unwrap_or(0);
  ```

- `const fn`比C++的`constexpr`清晰

- 宏系统很强，不需要反射也可以在编译期做很多事，极大地改善了使用体验

- 生态够用，包管理强

```toml
[dependencies]
base64 = "0.22.1"
bytes = "1.11.1"
chrono = "0.4.43"
html-escape = "0.2.13"
prost = "0.14.3"
rand = "0.10.0"
reqwest = { version = "0.13.2", features = ["json", "multipart"] }
scraper = "0.25.0"
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"
tempfile = "3.25.0"
thiserror = "2.0.18"
tokio = { version = "1.49.0", features = ["full"] }
tokio-util = "0.7.18"

[build-dependencies]
prost-build = "0.14.3"
```

- 巅峰性能；内存开销极小；适合有洁癖的程序员。会强迫你思考一个值是owned还是borrowed，但是带来的性能收益很大。

# 缺点

- 异步依旧还在发展期（比如async stream还未稳定）；`select!`宏会影响LSP代码补全
- 对语言的使用者的要求极高，必须非常熟悉生命周期和内存管理
