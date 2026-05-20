---
title: Some experience in crawling
tags: [misc]
---

### Introduction

I’ve been writing web scrapers since I was in middle school.

Back then, the internet was flooded with people selling basic scraping courses. Looking back over the past decade, while the tech stack has evolved, the core logic of scraping has remained exactly the same. Today, I want to skip the textbook fluff and share some real-world insights, tech stack opinions, and the actual bottlenecks that will make or break your scraper.

---

### 1. The Two Ultimate Approaches: Performance vs. Capabilities

When you strip away the marketing buzzwords, all scraping solutions fall into one of two categories:

#### Route A: Direct HTTP Requests (HttpClient)

- **The Stack**: Axios, OkHttp, Python Requests, Jsoup, etc.
- **The Good**: **Insanely fast and highly efficient.** You are fetching raw HTML or hitting APIs directly, skipping the heavy overhead of browser rendering.
- **The Bad**: A very low ceiling. In an era of obfuscated JS, dynamic tokens, and advanced device fingerprinting, this method gets blocked almost instantly on modern websites.

#### Route B: Browser Automation (Headless Browsers)

- **The Stack**: Selenium (legacy WebDriver), or the modern industry standard: **Playwright**.
- **The Good**: **The highest capability ceiling.** Since it controls a real browser, it executes JS flawlessly and handles dynamic rendering naturally.
- **The Bad**: **Slow.** Extremely resource-intensive.

**Pro-Tip on Browser Automation:**
In the past, everyone defaulted to Selenium. Today, **Playwright is the undisputed king**. Its API is vastly more powerful, and the out-of-the-box developer experience (UX) blows Selenium completely out of the water.

---

### 2. Languages & Parsers: Dispelling the "Python is King" Myth

In theory, you can write a scraper in any language that can make network requests and parse strings. Yet, many beginners fell into the trap of thinking Python is the _only_ choice.

**To be honest, I hate writing scrapers in Python—its typing system is garbage.** When you are building large-scale, complex scraping pipelines, the lack of strong static typing becomes a debugging nightmare.

- **My Tech Stack Evolution**:
  - **The Past**: `Kotlin` + `Jsoup` (JVM power coupled with Kotlin's sweet syntax made parsing HTML incredibly smooth).
  - **The Present**: `TypeScript` + `Playwright` (perfectly aligned with the modern frontend ecosystem).

#### Parsing the Target:

We are always scraping the same four resources: **HTML, JS, Images, and JSON**. To locate elements in HTML, you have two main routes: **CSS Selectors** and **XPath**.

- **XPath**: A legendary tool in web history. It acts like a query language for XML/HTML and is incredibly powerful for complex sibling/parent traversals. I used to love it.
- **CSS Selectors**: My current go-to. It feels virtually the same as XPath in terms of daily utility, but it has broader native support and aligns better with modern frontend practices.
- **Regular Expressions (Regex)**: **You 100000% must master this.** You will constantly encounter malformed HTML or unstructured text. When selectors fail, Regex is your only lifesaver.

---

### 3. The Real Great Divide: "Parsing" vs. "Acquiring"

If you think writing a CSS selector to extract some text makes you a "scraper developer," you've barely scratched the surface.

**The hardest part of scraping is never parsing the data; it’s acquiring it.**

Today’s web is a heavily guarded fortress. To get the data, you have to play a cat-and-mouse game with anti-scraping engineers. The real bosses you’ll face include:

1.  **Encrypted/Signed Data**: The data isn't in the HTML; it’s loaded via Ajax, and the request parameters are secured with proprietary MD5/AES/RSA signatures. You have to **reverse-engineer their obfuscated JavaScript** to figure out how the signature is generated.
2.  **Authentication & Session Management**: Navigating complex login flows, managing active tokens/cookies, and bypassing behavioral captchas.
3.  **Enterprise Firewalls (e.g., Cloudflare)**: Dealing with JS challenges, TLS fingerprinting, and Canvas/WebGL device fingerprinting that block you before your request even hits the server.
4.  **Device Spoofing**: Many sites strictly monitor for mobile vs. desktop footprints. You must perfectly mimic viewports, User-Agents, and browser global objects (`navigator`).

Solving these problems is what separates the juniors from the seniors.

---

### 4. The Philosophy of Scraping: High Concurrency is Worthless. Single-Thread + Blocking is the GOAT.

When I was younger, I fell for the hype of high-performance frameworks like _Scrapy_ (think of it as the Spring Boot of scrapers—clunky and heavy). I wanted massive concurrency and blazing-fast speeds.

But when you target high-value, heavily protected platforms, you quickly learn a harsh truth:

> **High concurrency is completely worthless in the face of strict rate-limiting.**

If you crank your concurrency up to 100, your IP will get blacklisted within seconds, and you might even get your entire proxy subnet banned.

The true art of scraping is the art of **stealth**. If you don’t `sleep` for a few minutes between tasks, you are begging to get caught.

In production, **a single-threaded pipeline with strategic blocking (or low-frequency concurrency with randomized delays) is the undisputed GOAT**. Let the scraper breathe. Match the rhythm of a slow, distracted human user. Slow and steady is the only way to actually cross the finish line.

### Conclusion

Web scraping is an endless game of chess. From simple HTTP GET requests to modern TLS fingerprint bypasses, the field has evolved dramatically, but the thrill remains the same.

Hopefully, these thoughts save you some pain before you write your next target URL. And remember: **keep it ethical, and mind the legal boundaries.**
