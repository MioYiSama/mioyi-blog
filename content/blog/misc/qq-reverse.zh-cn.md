---
title: 逆向手机 QQ（QQNT）数据库全过程
tags: [杂项]
---

> 目标：从一台 iPhone 上导出 QQ 号 `<本号QQ>` 与某位好友 `<对方QQ>` 的完整私聊记录。
> 手上只有 QQ 这个 App 的「容器目录」和一个空的 Python 虚拟环境。
> 结果：完整解密 `nt_msg.db`（227 MB，55635 页全部 HMAC 校验通过），导出 24341 条消息为 JSON。
>
> 这篇文章如实记录整个过程 —— 包括所有走过的弯路、试错、查到的资料和最终的突破。技术栈：macOS + Python 3.13 + pycryptodome。

---

## 0. 起点：我拿到了什么

最初的工作目录 `/Users/<user>/Downloads/QQ` 长这样：

```
.DS_Store
.lock                 (3.5M)
.venv/                ← 用户给的 Python 虚拟环境（uv 创建，里面啥都没装）
Container/            ← App 沙盒
iTunesMetadata.plist
Payload/              ← QQ.app
```

这份数据的来历：用 **iMazing 把 QQ 这个 App 导出为 `QQ.imazingapp`**，再把后缀名改成 `.zip` 解压，得到的就是上面这个目录。`Payload/ + iTunesMetadata.plist + Container/` 这种结构是 iOS App 解包导出的标准产物 —— `Container` 是 QQ 的沙盒数据，`Payload/QQ.app` 是应用包本身。

> 注意：`.imazingapp` 导出的是 **App 沙盒 + 应用包**，**不含系统钥匙串** —— 这一点正是后文卡住、最终改用「加密备份」的根本原因。

第一个判断：聊天记录在 `Container` 里。

---

## 1. 定位聊天记录文件

### 1.1 先翻 Container

```bash
find Documents Library AppGroups -maxdepth 3 -type d
```

一眼就看到关键目录 `Documents/nt_qq_<hash·已脱敏>` —— `nt_` 前缀是 **QQNT**（新版 QQ 统一内核）的标志。

进去却只有一个 `storages/yffm_v1.db`。打开看头部：

```
00000000: 5351 4c69 7465 2068 6561 6465 7220 3300  SQLite header 3.
00000020: 5151 5f4e 5420 4442 2400 0000 1208 6453  QQ_NT DB$.....dS
00000040: 0948 4d41 435f 5348 4131 28df b6aa b306  .HMAC_SHA1(.....
```

注意：标准 SQLite 的魔数是 `SQLite format 3\0`，这里被改成了 **`SQLite header 3\0`**，后面还有 `QQ_NT DB` 和 `HMAC_SHA1`。这是 QQNT 的 **SQLCipher 加密库**。

但 `yffm_v1.db` 不是主消息库。继续全局找：

```bash
find Container -name '*.db'
```

### 1.2 真正的消息库

输出里出现了两套 NT 库（两个账号）：

```
Documents/QQNT/DB/nt_db/nt_qq_<hash2·已脱敏>/nt_msg.db   ← 含 gpro_v1-6_<小号QQ>.db
Documents/QQNT/DB/nt_db/nt_qq_<path_hash·已脱敏>/nt_msg.db   ← 含 gpro_v1-6_<本号QQ>.db
```

`gpro_v1-6_<uin>.db` 这个文件名直接暴露了账号归属 —— 所以 **`nt_qq_<path_hash·已脱敏>` 这个文件夹属于 <本号QQ>**。`nt_msg.db` 就是它的消息库。

还发现了旧版库：

```
Documents/contents/<本号QQ>/QQ.db        ← 旧版 QQ 消息库
Documents/contents/<本号QQ>/QQ_Mix.db
```

`nt_msg.db` 的头部和 `yffm_v1.db` 一样：`SQLite header 3` + `QQ_NT DB` + per-DB 的 8 字节盐（这个库是 `<rand·已脱敏>`）+ `HMAC_SHA1`。每个库盐不同，但 **密钥共享**。

> 阶段结论：聊天记录在 `nt_msg.db`（加密），但旧版 `QQ.db` 可能是明文，先看哪个有这个人。

---

## 2. 弯路一：先看旧库 QQ.db（明文，但没有这个人）

`QQ.db` 头部是标准 `SQLite format 3\0` —— **未加密**！直接用 `sqlite3` 打开：

```sql
SELECT name FROM sqlite_master WHERE type='table';
-- tb_c2cMsg_1984491526, tb_c2cMsg_249159438, ... tb_TroopMsg_xxx, tb_recentC2CMsg ...
```

私聊在 `tb_c2cMsg_<对方uin>` 表里，内容字段是**明文**的（比如直接能读到 `对方撤回了一条消息`）。

但是 —— **没有 `tb_c2cMsg_<对方QQ>` 这张表**。把 `tb_recentC2CMsg`（最近会话）也翻了，里面是另外十几个好友，没有 <对方QQ>。

再用 `grep` 在 `QQ.db` / `QQ_Mix.db` 里搜 `<对方QQ>`，有命中，但都在 `tb_TroopMem`（群成员表）里 —— 也就是说，**<对方QQ> 只是和我同群，旧库里没有我俩的私聊**。

> 弯路结论：旧库白看了。这个人的私聊只可能在加密的 `nt_msg.db` 里。**必须解密。**

---

## 3. 解密 `nt_msg.db` 需要密钥 —— 钥匙在哪？

### 3.1 弯路二：想反编译 App 二进制

`Payload/QQ.app/` 里只有一个 `Info.plist` —— 主二进制被剥掉了。**没法静态分析解密逻辑**，只能靠数据本身 + 公开资料。

### 3.2 弯路三：把整个容器翻个底朝天找密钥

QQNT 桌面版的 key 是从内存里抓的；手机版理论上存在某处。我做了地毯式搜索：

- `ConfigStorage/launchDB_<本号QQ>.conf` —— 名字像"DB 启动参数"，结果里面的 `QQMessageDBConfigInfoKey` 只是消息计数统计，不是密钥。
- `Library/APNewKeyInfo.plist` —— 推送密钥，无关。
- `nt_open_id_mmkv` / `nt_mmkv_global_misc` / 各种 mmkv —— 没有。
- 主偏好 `com.tencent.mqq.plist` —— 没有 db key。
- 写脚本扫描**所有** < 2 MB 的非 db 文件，提取"独立 32 字符可打印 token"：结果全是表情包的 MD5 哈希，没有数据库密钥。

旁边倒是发现了关键文件 —— **`nt_msg.db-first.material` / `nt_msg.db-last.material`**（20 KB，高熵）。这是 QQNT 存"加密后的数据库密钥"的地方。两个文件开头都是相同的 16 字节 `db10 29ee 2e9c 1a17 becd 526d 67bb 68d9`（后面会发现这就是盐）。

### 3.3 关键认识：iOS 上 key 在钥匙串（Keychain）里

查资料确认：iOS 上消息 App 的数据库密钥通常放在**系统钥匙串**里（Signal、WhatsApp 都是如此）。`.material` 文件是被钥匙串里的一把 key 加密的。

而我手上的是 **App 容器**，里面**没有钥匙串**。

> 死结：要解密，必须拿到钥匙串。而 App 容器导出（=用户最初给的东西）不含钥匙串。

参考资料：

- [QQDecrypt: NTQQ 解密数据库](https://qqbackup.github.io/QQDecrypt/decrypt/decode_db.html)
- [ElcomSoft: Extracting and Decrypting iOS Keychain](https://blog.elcomsoft.com/2020/08/extracting-and-decrypting-ios-keychain-physical-logical-and-cloud-options-explored/)

---

## 4. 不越狱拿钥匙串：加密备份是唯一通道

向用户说明了 iOS 钥匙串的三种状态：

| 方式                        | 钥匙串能否离线解                                      |
| --------------------------- | ----------------------------------------------------- |
| 导出原始文件（=已有的容器） | ❌ 根本没有钥匙串                                     |
| 普通备份（不加密）          | ❌ 钥匙串用设备硬件密钥锁着，只能还原回原机           |
| **加密备份（设密码）**      | ✅ 钥匙串改用**备份密码派生的密钥**重新封装，可离线解 |

原理：只有**加密**的 iOS 备份，securityd 才会把钥匙串项用备份口令重新封装，从而脱离设备硬件密钥。这是不越狱拿到 key 的唯一路。

用户有 iMazing。这里还澄清了一个易错点：iMazing 的「**导出原始文件**」拿到的就是我已经有的 App 沙盒文件（没有钥匙串），「导出全部数据」同理。必须选「**备份**」并**勾选加密 + 设密码**。

用户做了加密备份，密码 `<备份密码>`，路径 `~/Library/Application Support/iMazing/Backups`。

---

## 5. 解密 iOS 加密备份

### 5.1 备份结构

```
<设备ID·已脱敏>/
  Manifest.plist   ← IsEncrypted=true, BackupKeyBag(1712B), ManifestKey
  Manifest.db      ← 405 MB，加密的文件清单
  51/51a4616e576dd33cd2abadfea874eb8ff246bf0e   ← 钥匙串文件
  ...（按 fileID 前两位 hash 分桶）
```

钥匙串文件的 fileID 是 `SHA1("KeychainDomain-keychain-backup.plist")` = `51a4616e576dd33cd2abadfea874eb8ff246bf0e` —— 算出来后直接在备份里找到了，5.4 MB。

环境准备（venv 是 uv 创建的，没有 pip）：

```bash
uv pip install --python .venv/bin/python pycryptodome
```

### 5.2 解开 BackupKeyBag（脚本 `bk.py`）

iOS 备份的 keybag 是 TLV 格式（4 字节 tag + 4 字节大端长度 + value）。流程：

1. **口令派生**（iOS 10.2+ 双层 PBKDF2）：
   ```python
   tmp  = PBKDF2-SHA256(password, DPSL, DPIC=10_000_000, 32)
   pkey = PBKDF2-SHA1(tmp, SALT, ITER=10000, 32)
   ```
2. **解每个 class key**：对 `WPKY` 做 **RFC 3394 AES key unwrap**（KEK=pkey）。校验值 `A == 0xA6A6A6A6A6A6A6A6` 说明解对了。

结果：14 个 class key 全部解开。

3. **解 `Manifest.db`**：`ManifestKey` = 4 字节 class（小端）+ 40 字节 wrapped key。unwrap 后 AES-256-CBC（零 IV）解密整库。

```
keybag VERS=5 TYPE=1 ITER=10000 classes=14 DPSL=yes DPIC=10000000
unlocked 14 class keys
Manifest class=3 key=<已脱敏>...
Manifest.db header: b'SQLite format 3\x00'   ← 解对了
```

4. **解钥匙串文件**：从 `Manifest.db` 的 `Files` 表取它的 NSKeyedArchiver blob → 拿到 `ProtectionClass` 和 wrapped 的 per-file key → unwrap → AES-CBC 解密 5.4 MB 文件：

```
decrypted keychain head: b'bplist00'   ← 是合法 binary plist
```

钥匙串到手：4439 个 `genp`、460 个 `inet`、563 个 `keys`、12 个 `cert`。

---

## 6. 弯路四：钥匙串项的 GCM 解密（off-by-one 折腾很久）

每个钥匙串项的 `v_Data` 结构是：

```
version(4 LE)=3 | class(4 LE) | wrapped_key_len(4 LE)=40 | wrapped_key(40) | GCM 密文+tag
```

第一版尝试：unwrap 出 key，然后 pycryptodome 的 AES-GCM（零 nonce）解 —— **全部失败**，5474 个项一个都没解出来。

排查发现一个关键现象：

- 对 wrapped_key 做 RFC3394 unwrap，**class 6/7/8 全部成功**（auth 通过），9/10/11 全部失败。
- 9/10/11 是 `…ThisDeviceOnly` 类，被设备密钥绑定，**加密备份里也解不出来**（预期内，无解）。

所以 key 是对的，但 **GCM 这层错了**。零 nonce 解出来是乱码 —— 说明 nonce 不对。

这一步不能再瞎猜，去找权威实现。`dunhamsteve/ios`（Go 写的 iOS 备份提取工具）的源码给出了答案：

```go
// crypto/gcm/gcm.go, Open():
if len(nonce) != gcmNonceSize {
    // counter is all zeros for apple's blank iv
    // counter = [16]byte{0}      ← J0 = 全零块
}
g.cipher.Encrypt(tagMask[:], counter[:])   // tagMask = E(0^16)
gcmInc32(&counter)                          // counter -> 0...0001
g.counterCrypt(out, ciphertext, &counter)   // 数据从 counter=1 开始
```

**Apple 的"空 IV" GCM**：J0 = 全零块（而不是标准 12 字节 nonce 的 `nonce||00000001`），数据 keystream 从 **counter=1** 开始。这跟 pycryptodome 的零 nonce 差了**一个计数块**。

用 AES-CTR（前缀 12 字节零 + 32 位计数器，**初值 1**）实现，瞬间解开：

```python
ctr = Counter.new(32, prefix=b"\x00"*12, initial_value=1)
plain = AES.new(key, AES.MODE_CTR, counter=ctr).decrypt(edata[:-16])
```

```
class7 plaintext head: b'1\x82\x02\xb40\x08\x0c\x04musr...'  ← DER 编码的钥匙串属性
```

参考：[dunhamsteve/ios](https://github.com/dunhamsteve/ios) · [xperylabhub/ios_keychain_decrypter](https://github.com/xperylabhub/ios_keychain_decrypter)

---

## 7. 解析钥匙串、寻找 QQ 的数据库密钥

解出的明文是 **DER**：`SET OF SEQUENCE { UTF8String key, value }`，字段有 `musr/pdmn/svce/acct/agrp/v_Data` 等。写了个小 DER 解析器（`kc.py`），扫出 357 个 Tencent/QQ 项。

### 弯路五：以为找到了 key，结果不是

逐个看 QQ 访问组（`com.tencent.mqq` / `com.tencent.generickeychain` / `com.tencent.ww`）的 97 个项、所有恰好 32 字符的值、所有含 `db/cipher/kernel/nt_qq/yffm/...` 关键字的项 —— **都不是数据库密钥**。

但解码 QQ 的几个 NSKeyedArchiver blob 时，`com.tencent.mqq` 这一项存了个 36 字符 token：

```
== com.tencent.mqq ==  '<已脱敏token>'
```

看起来太像 key 了。于是写了 SQLCipher 验证器（用页 HMAC 当 oracle）去试 —— **不匹配**。试了各种参数组合，还是不匹配。

> 弯路结论：这个 token 不是数据库密钥。而且我对 SQLCipher 格式的建模可能也错了。

---

## 8. 重新看文件结构 + 关键资料

### 8.1 `nt_msg.db` 不是"盐在最前面"的标准 SQLCipher

重看头部：前 ~96 字节是**明文元数据**（`QQ_NT DB`、`HMAC_SHA1` 都能直接读到），`0x4a` 之后到第一页末尾**全是零**。

```python
print(len(d)%1024, len(d)%4096)   # -> 0, 1024
```

文件是 1024 的整数倍、但不是 4096 的整数倍 → **每页 1024？** 再看偏移 **1024**：

```
<盐·已脱敏> cc97f803...
```

**这 16 字节和 `.material` 文件开头一模一样！** 这就是 **SQLCipher 的盐**。

真相浮现：文件 = **1024 字节明文 QQ 头** + 一个**标准 SQLCipher 库**（从偏移 1024 开始，盐 + 加密页）。

### 8.2 资料：手机版 QQNT 的密钥推导公式

桌面版资料（page=4096）对不上手机版。搜安卓版（同样的 `QQ_NT DB` 格式）：

- [Android QQ NT 版数据库解密 - yllhwa](https://blog.yllhwa.com/blog/android_qq_nt_database/)
- [qq-win-db-key / 教程 - NTQQ (Android).md](<https://github.com/QQBackup/qq-win-db-key/blob/master/%E6%95%99%E7%A8%8B%20-%20NTQQ%20(Android).md>)

`qq-win-db-key` 的 Android 教程给出了**精确公式**：

```
QQ_UID_hash = md5(uid)                              # uid 形如 u_xxxxxxxx
QQ_path_hash = md5(md5(uid) + "nt_kernel")          # = nt_qq_ 文件夹名
key          = md5(QQ_UID_hash + rand)              # 32 位小写 hex，当作 SQLCipher 口令
```

其中 `rand` = 文件头 `QQ_NT DB` 后那串可读字符（本库 = `<rand·已脱敏>`）。

SQLCipher 参数：**剥掉 1024 字节头**，`kdf_iter=4000`、`HMAC_SHA1`。

---

## 9. 找 uid、验证、算出密钥

公式需要 `uid`。在容器里搜 `u_` token 与账号的关联：

```bash
grep -raoE 'u_[A-Za-z0-9_-]{22}' Container | sort | uniq -c | sort -rn
# 登录相关的 plist/mmkv 里反复出现 u_<本号uid·已脱敏>
```

**关键验证手段**：`md5(md5(uid)+"nt_kernel")` 必须等于文件夹名 `<path_hash·已脱敏>`。逐个试候选 uid：

```
*** MATCH uid=u_<本号uid·已脱敏> ***
    QQ_UID_hash = <uid的md5·已脱敏>
    DB key      = <数据库密钥·已脱敏>
```

uid 对上了，密钥 = **`<数据库密钥·已脱敏>`**。

（事后明白：QQNT 手机版的库密钥**根本不在钥匙串里**，而是从 uid 推导的。但走钥匙串这一路并非全白费 —— 它帮我确认了本号的 uid 和登录信息，且方法本身可复用。）

---

## 10. 验证密钥 + 全量解密

### 10.1 用页 HMAC 当 oracle 验证

SQLCipher 每页末尾有 `IV + HMAC`。如果 key 和参数对，page-1 的 HMAC 必然匹配。`sqlcipher_try.py` 暴力搜参数空间：

```
MATCH key=ascii page_size=4096 kdf_iter=4000 kdf_prf=sha512 hmac=sha1 reserve=48
```

注意：**page_size 实际是 4096**（头部那个 `0400` 字节是误导，它落在被改写的元数据区里）。最终参数：

> 剥 1024 字节头 → 标准 SQLCipher：page=4096、kdf_iter=4000、KDF=PBKDF2-HMAC-**SHA512**、页 HMAC=**SHA1**、AES-256-CBC、reserve=48。

### 10.2 逐页解密（`decrypt_db.py`）

- 盐 = 偏移 1024 起的 16 字节。
- `enc_key = PBKDF2-SHA512(passphrase, salt, 4000, 32)`
- `hmac_key = PBKDF2-SHA512(enc_key, salt⊕0x3a, 2, 32)`
- 每页：取页尾 IV → AES-256-CBC 解密页体；page 1 前面补回标准 `SQLite format 3\0` 魔数。

```
decrypted 55635 pages, hmac-mismatches=0 -> work/nt_msg.plain.db
=== header === SQLite format 3.
```

**55635 页 HMAC 零失配** —— 完美解密。表结构出现：`c2c_msg_table`、`group_msg_table`、`nt_uid_mapping_table` …

---

## 11. 找到 <对方QQ> 的会话

`nt_msg.db` 用数字列名、用 uid（不是 uin）标识人。`nt_uid_mapping_table` 里却**没有** <对方QQ>。

直接在解密库里 grep：

```
&uin=<对方QQ>&uid=u_<对方uid·已脱敏>
```

**<对方QQ> = uid `u_<对方uid·已脱敏>`** —— 而它正是 `c2c_msg_table` 里消息量第一的对端（24341 条）！

列含义摸清：

| 列      | 含义                                          |
| ------- | --------------------------------------------- |
| `40021` | 对端 uid（会话主键，整条会话恒定）            |
| `40020` | 发送者 uid                                    |
| `40033` | 发送者 uin（真正的发送方）                    |
| `40030` | **对端 uin（恒定 = <对方QQ>，不是发送者！）** |
| `40050` | unix 时间戳                                   |
| `40800` | 消息元素（protobuf）                          |

### 弯路六：方向判断错了

一开始用 `40030` 当发送者，导致我发的消息也被标成"对方"。核对后才发现 `40030` 是恒定的对端号，真正发送者要看 `40033`（或 `40020` 的 uid 与本号 uid 比较）。修正后：我 10269 条 / 对方 13652 条 / 系统 420 条。

---

## 12. 解析消息内容（protobuf）+ 导出 JSON

`40800` 是消息元素的 protobuf。写了个通用 protobuf 解析器递归提取，定位到文本在 **`元素 → 45101`**：

```
[40800.45101] '（示例文本消息·已脱敏）'
```

各元素类型：

| 字段            | 类型                                        |
| --------------- | ------------------------------------------- |
| `45101`         | 文本                                        |
| `45402`         | 图片（文件名 + md5）                        |
| `45815 / 47602` | 表情 / 大表情描述（`[动画表情]`、`[崇拜]`） |
| `49154`         | 商城表情                                    |
| `48271`         | 灰条系统提示（JSON）                        |
| `47402–47423`   | 引用回复包裹                                |
| `47702–47704`   | 文件/视频                                   |
| `80800–80999`   | ark 卡片                                    |

`export_json.py` 全量导出 24341 条，每条含 `msg_id / seq / sender_uin / sender_uid / sender_name / is_me / time / time_str / text / elements`。元素分类统计：

```
text 17466, image 4898, reply 1055, face 854, marketface 821,
struct_card 301, ark_card 261, video 106, share 91, greytip 28,
poke_or_superface 546, file_or_video 30, unknown 6
```

最终样本，方向正确、读起来自然：

```
[2025-02-27 18:38:11] 对方: （消息内容·已脱敏）
[2025-02-27 18:47:33] <我的昵称>: （消息内容·已脱敏）
[2025-02-27 18:47:58] 对方: （消息内容·已脱敏）
```

---

## 13. 交付物与脚本清单

| 文件                          | 说明                                              |
| ----------------------------- | ------------------------------------------------- |
| `chat_<本号QQ>_<对方QQ>.json` | 最终聊天记录，24341 条，~11 MB                    |
| `work/nt_msg.plain.db`        | 解密后的完整明文 SQLite（含所有会话/群聊）        |
| `work/keychain-backup.plist`  | 解密后的钥匙串                                    |
| `bk.py`                       | 解 iOS 加密备份 keybag + Manifest.db + 钥匙串文件 |
| `kc.py`                       | 解钥匙串项（Apple blank-IV GCM）+ DER 解析        |
| `decrypt_db.py`               | QQNT 库解密（剥头 + SQLCipher 逐页）              |
| `sqlcipher_try.py`            | 用页 HMAC 验证 key/参数                           |
| `export_json.py`              | 解析消息表 + protobuf，导出 JSON                  |

---

## 14. 复盘：哪些是弯路，哪些是关键

**走过的弯路**

1. 指望旧版 `QQ.db`（明文但没这个人）。
2. 想反编译 App 二进制（被剥了）。
3. 在容器里地毯式找密钥（根本不在容器里）。
4. 钥匙串项 GCM 用标准零 nonce（差一个计数块，Apple 用 blank-IV）。
5. 把 `com.tencent.mqq` 的 36 字符 token 当 key（不是）。
6. 把 `nt_msg.db` 当"盐在最前"的标准 SQLCipher（实际前面有 1024 字节 QQ 头）。
7. 用 `40030` 判断消息方向（那是恒定对端号，真发送者是 `40033`）。

**真正的关键突破**

- 认出加密备份是不越狱拿钥匙串的唯一通道。
- 从 `dunhamsteve/ios` 源码得到 Apple blank-IV GCM 的实现细节。
- 偏移 1024 处的 16 字节与 `.material` 文件相同 → 认出真正的 SQLCipher 盐和 1024 字节头。
- 查到手机版 `key = md5(md5(uid)+rand)` 公式，并用文件夹哈希 `md5(md5(uid)+"nt_kernel")` 反验 uid。
- 全程用**页 HMAC 当判定 oracle**，让"对/错"有确定答案，不靠肉眼猜。

**一句话总结**：QQNT 手机版 `nt_msg.db` = `1024 字节明文头 + 标准 SQLCipher(page=4096, kdf_iter=4000, PBKDF2-HMAC-SHA512, HMAC-SHA1, AES-256-CBC)`，口令 = `md5(md5(uid) + 头部 rand 串)`。uid 可从设备数据找到、用 nt_qq 文件夹哈希验证。

---

## 参考资料

- [QQDecrypt：NTQQ 解密数据库](https://qqbackup.github.io/QQDecrypt/decrypt/decode_db.html)
- [qq-win-db-key（全平台 QQ 数据库解密）](https://github.com/QQBackup/qq-win-db-key) · [Android 教程](<https://github.com/QQBackup/qq-win-db-key/blob/master/%E6%95%99%E7%A8%8B%20-%20NTQQ%20(Android).md>)
- [Android QQ NT 版数据库解密 - yllhwa](https://blog.yllhwa.com/blog/android_qq_nt_database/)
- [Mythologyli/qq-nt-db](https://github.com/Mythologyli/qq-nt-db)
- [dunhamsteve/ios（iOS 备份/钥匙串提取，Go）](https://github.com/dunhamsteve/ios)
- [xperylabhub/ios_keychain_decrypter](https://github.com/xperylabhub/ios_keychain_decrypter)
- [ElcomSoft：Extracting and Decrypting iOS Keychain](https://blog.elcomsoft.com/2020/08/extracting-and-decrypting-ios-keychain-physical-logical-and-cloud-options-explored/)
- [Hakuuyosei/QQHistoryExport](https://github.com/Hakuuyosei/QQHistoryExport)

---

_本文记录的是对作者本人账号、本人设备数据的取证式导出，用于个人聊天记录备份。_
