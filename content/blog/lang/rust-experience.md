---
title: "My Experience of Using Rust"
tags: [programming-language]
---

# Advantages

- Error handling is a step ahead of Go, more robust. A more robust service is less worrisome.
  - Error declaration (very intuitive)

  ```rust
  #[derive(Debug, thiserror::Error)]
  pub enum InfoFetchError {
      #[error("Failed to send HTTP request: {0}")]
      SendHttpRequestError(reqwest::Error),
      #[error("HTTP response error: {0}")]
      HttpResponseError(reqwest::Error),
      #[error("HTTP response body error: {0}")]
      HttpResponseBodyError(reqwest::Error),
      #[error("Script element not found")]
      NoScriptError,
      #[error("Script processing error")]
      ProcessScriptError,
      #[error("JSON parsing error: {0}")]
      JsonParseError(#[from] serde_json::Error),
      #[error("No PlayItem")]
      NoPlayItemError,
  }
  ```

  - Error handling (very robust, forces error checking)

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

- Pattern matching may have a bit of a learning curve, but it is very powerful once mastered.

  ```rust
  // Process guardian
  let token = CancellationToken::new();
  let t = token.clone();
  tokio::spawn(async move {
      match t.run_until_cancelled(process.wait()).await {
          // ffmpeg process finished
          Some(Ok(_)) => t.cancel(),
          // OS wait failed
          Some(Err(_)) => t.cancel(),
          // token cancelled
          None => {
              if let Err(_) = process.kill().await {
                  return;
              }
          }
      }
  });
  ```

- Union types are powerful, easily expressing "or" semantics with zero-cost abstractions.

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

- The trait system is strong, and when combined with generics, it can express complex semantics. It can also add functionality to structs from other modules.

- Modules are much easier to use than in C++, as they don't require following the order of usage within the same file, and the compiler automatically checks for circular references.

- The compiler is powerful and can catch many errors.

- Collections and iterator APIs are complete.

  ```rust
  let overlap = self
      .danmakus
      .iter()
      .position(|dm| dm == first)
      .map(|i| self.danmakus.len() - i)
      .unwrap_or(0);
  ```

- `const fn` is clearer than C++'s `constexpr`.

- The macro system is very powerful, allowing many things to be done at compile-time without needing reflection, greatly improving the user experience.

- The ecosystem is sufficient, and package management is strong.

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

- Peak performance; minimal memory overhead; suitable for programmers with a perfectionist mindset. It forces you to think about whether a value is owned or borrowed, but the performance gains are significant.

# Disadvantages

- Asynchronous programming is still in development (for example, async streams are not stable yet); the `select!` macro can interfere with LSP code completion.
- The language has a high learning curve, requiring a deep understanding of lifetimes and memory management.
