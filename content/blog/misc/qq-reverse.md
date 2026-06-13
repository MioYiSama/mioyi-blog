---
title: "Reverse-Engineering the Mobile QQ (QQNT) Database: A Complete Walkthrough"
tags: [misc]
---

> Goal: Export the complete private chat history between QQ account `<my-qq>` and a friend `<their-qq>` from an iPhone.
> All I had: the QQ app's "Container directory" and an empty Python virtual environment.
> Result: Fully decrypted `nt_msg.db` (227 MB, 55,635 pages, all HMACs verified), exported 24,341 messages as JSON.
>
> This article is an honest record of the entire process — every detour, failed attempt, reference found, and final breakthrough. Tech stack: macOS + Python 3.13 + pycryptodome.

---

## 0. Starting Point: What I Had

The initial working directory `/Users/<user>/Downloads/QQ` looked like this:

```
.DS_Store
.lock                 (3.5M)
.venv/                ← User-provided Python venv (created by uv, empty)
Container/            ← App sandbox
iTunesMetadata.plist
Payload/              ← QQ.app
```

Origin of the data: **iMazing exported the QQ app as `QQ.imazingapp`**, then renamed to `.zip` and extracted, giving the directory above. The structure of `Payload/ + iTunesMetadata.plist + Container/` is standard for iOS app package extraction — `Container` is QQ's sandbox data, `Payload/QQ.app` is the application bundle itself.

> Note: `.imazingapp` export contains **App sandbox + app bundle**, but **not the system Keychain** — this is precisely the reason for the later deadlock, and why the path switched to "encrypted backup".

First assumption: chat records are inside `Container`.

---

## 1. Locating the Chat Database Files

### 1.1 Exploring the Container

```bash
find Documents Library AppGroups -maxdepth 3 -type d
```

Immediately spotted the key directory `Documents/nt_qq_<hash·redacted>` — the `nt_` prefix is the hallmark of **QQNT** (the new unified QQ kernel).

Inside, there was only a `storages/yffm_v1.db`. Looking at its header:

```
00000000: 5351 4c69 7465 2068 6561 6465 7220 3300  SQLite header 3.
00000020: 5151 5f4e 5420 4442 2400 0000 1208 6453  QQ_NT DB$.....dS
00000040: 0948 4d41 435f 5348 4131 28df b6aa b306  .HMAC_SHA1(.....
```

Note: standard SQLite magic is `SQLite format 3\0`, but here it's changed to **`SQLite header 3\0`**, followed by `QQ_NT DB` and `HMAC_SHA1`. This is QQNT's **SQLCipher encrypted database**.

However, `yffm_v1.db` is not the main message database. Continuing the global search:

```bash
find Container -name '*.db'
```

### 1.2 The Real Message Database

The output revealed two sets of NT databases (two accounts):

```
Documents/QQNT/DB/nt_db/nt_qq_<hash2·redacted>/nt_msg.db   ← contains gpro_v1-6_<alt-qq>.db
Documents/QQNT/DB/nt_db/nt_qq_<path_hash·redacted>/nt_msg.db   ← contains gpro_v1-6_<my-qq>.db
```

The filename `gpro_v1-6_<uin>.db` directly exposes account ownership — so **`nt_qq_<path_hash·redacted>` belongs to <my-qq>**. `nt_msg.db` is its message database.

Also found the legacy databases:

```
Documents/contents/<my-qq>/QQ.db        ← Legacy QQ message database
Documents/contents/<my-qq>/QQ_Mix.db
```

The header of `nt_msg.db` is identical to `yffm_v1.db`: `SQLite header 3` + `QQ_NT DB` + per-DB 8-byte salt (for this db: `<rand·redacted>`) + `HMAC_SHA1`. Each database has a different salt, but **they share the same key**.

> Phase conclusion: chat records are in `nt_msg.db` (encrypted), but the legacy `QQ.db` might be plaintext; let's check which one contains this person.

---

## 2. Detour 1: Checking the Legacy QQ.db (Plaintext, But No Match)

`QQ.db` has the standard `SQLite format 3\0` header — **unencrypted**! Opened directly with `sqlite3`:

```sql
SELECT name FROM sqlite_master WHERE type='table';
-- tb_c2cMsg_1984491526, tb_c2cMsg_249159438, ... tb_TroopMsg_xxx, tb_recentC2CMsg ...
```

Private chats are in `tb_c2cMsg_<their-uin>` tables, and the content column is **plaintext** (e.g., you can directly read `对方撤回了一条消息`).

But — **there is no `tb_c2cMsg_<their-qq>` table**. Also checked `tb_recentC2CMsg` (recent conversations), which only contained a dozen other friends, not `<their-qq>`.

Then grepped `<their-qq>` in `QQ.db` / `QQ_Mix.db` — there were hits, but all in `tb_TroopMem` (group member table). So **`<their-qq>` is only in the same group as me; there is no private chat between us in the legacy database**.

> Detour conclusion: the legacy database was a dead end. The private chat with this person can only be in the encrypted `nt_msg.db`. **Decryption is mandatory.**

---

## 3. Decrypting `nt_msg.db` Requires a Key — Where Is the Key?

### 3.1 Detour 2: Trying to Reverse-Engineer the App Binary

`Payload/QQ.app/` only contained an `Info.plist` — the main binary was stripped. **No static analysis of the decryption logic possible**. Had to rely on the data itself + public references.

### 3.2 Detour 3: Ransacking the Entire Container for the Key

For QQNT Desktop, the key is grabbed from memory; for mobile, it theoretically exists somewhere. I did a carpet-bomb search:

- `ConfigStorage/launchDB_<my-qq>.conf` — the name sounds like "DB startup config", but `QQMessageDBConfigInfoKey` inside was just message count statistics, not the key.
- `Library/APNewKeyInfo.plist` — push notification key, irrelevant.
- `nt_open_id_mmkv` / `nt_mmkv_global_misc` / various mmkv files — nothing.
- Main preferences `com.tencent.mqq.plist` — no db key.
- Wrote a script to scan **all** non-db files < 2 MB, extracting "standalone 32-character printable tokens": results were all MD5 hashes of sticker packs, not the database key.

However, a critical file was discovered — **`nt_msg.db-first.material` / `nt_msg.db-last.material`** (20 KB, high entropy). This is where QQNT stores the "encrypted database key". Both files start with the same 16 bytes `db10 29ee 2e9c 1a17 becd 526d 67bb 68d9` (later found to be the salt).

### 3.3 Key Insight: On iOS, the Key Is in the Keychain

References confirmed: on iOS, messaging apps usually store the database key in the **system Keychain** (Signal, WhatsApp follow this pattern). The `.material` files are encrypted by a key stored in the Keychain.

What I had was the **App Container**, which **does not contain the Keychain**.

> Deadlock: to decrypt, the Keychain is required. The App container export (what the user initially provided) does not include the Keychain.

References:

- [QQDecrypt: NTQQ Decrypt Database](https://qqbackup.github.io/QQDecrypt/decrypt/decode_db.html)
- [ElcomSoft: Extracting and Decrypting iOS Keychain](https://blog.elcomsoft.com/2020/08/extracting-and-decrypting-ios-keychain-physical-logical-and-cloud-options-explored/)

---

## 4. Getting the Keychain Without Jailbreak: Encrypted Backup Is the Only Way

Explained the three states of the iOS Keychain to the user:

| Method                                     | Can Keychain Be Decrypted Offline?                                                           |
| ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Raw file export (= the existing container) | ❌ No Keychain at all                                                                        |
| Regular backup (unencrypted)               | ❌ Keychain is locked by device hardware key, can only restore to the original device        |
| **Encrypted backup (with password)**       | ✅ Keychain is re-encrypted with a key derived from the backup password, decryptable offline |

Principle: only **encrypted** iOS backups cause `securityd` to re-encrypt Keychain items with a key derived from the backup password, freeing them from the device hardware key. This is the only way to get the key without jailbreaking.

The user had iMazing. Here, a common pitfall was clarified: iMazing's "**Export Raw Files**" gives exactly what I already had (App sandbox, no Keychain), and "Export All Data" is the same. Must choose "**Backup**" and **enable encryption + set a password**.

The user created an encrypted backup, password `<backup-password>`, path `~/Library/Application Support/iMazing/Backups`.

---

## 5. Decrypting the iOS Encrypted Backup

### 5.1 Backup Structure

```
<device-id·redacted>/
  Manifest.plist   ← IsEncrypted=true, BackupKeyBag(1712B), ManifestKey
  Manifest.db      ← 405 MB, encrypted file manifest
  51/51a4616e576dd33cd2abadfea874eb8ff246bf0e   ← Keychain file
  ...（bucketed by first two chars of fileID hash）
```

The Keychain file's fileID is `SHA1("KeychainDomain-keychain-backup.plist")` = `51a4616e576dd33cd2abadfea874eb8ff246bf0e` — calculated and found directly in the backup, 5.4 MB.

Environment setup (venv was created by uv, no pip):

```bash
uv pip install --python .venv/bin/python pycryptodome
```

### 5.2 Unlocking the BackupKeyBag (script `bk.py`)

The iOS backup keybag is in TLV format (4-byte tag + 4-byte big-endian length + value). Process:

1. **Password derivation** (iOS 10.2+ double-layer PBKDF2):
   ```python
   tmp  = PBKDF2-SHA256(password, DPSL, DPIC=10_000_000, 32)
   pkey = PBKDF2-SHA1(tmp, SALT, ITER=10000, 32)
   ```
2. **Unlock each class key**: perform **RFC 3394 AES key unwrap** on `WPKY` (KEK=pkey). The check value `A == 0xA6A6A6A6A6A6A6A6` confirms success.

Result: all 14 class keys unlocked.

3. **Decrypt `Manifest.db`**: `ManifestKey` = 4-byte class (little-endian) + 40-byte wrapped key. Unwrap, then AES-256-CBC (zero IV) decrypt the entire database.

```
keybag VERS=5 TYPE=1 ITER=10000 classes=14 DPSL=yes DPIC=10000000
unlocked 14 class keys
Manifest class=3 key=<redacted>...
Manifest.db header: b'SQLite format 3\x00'   ← decrypted correctly
```

4. **Decrypt the Keychain file**: from `Manifest.db`'s `Files` table, get its NSKeyedArchiver blob → obtain `ProtectionClass` and the wrapped per-file key → unwrap → AES-CBC decrypt the 5.4 MB file:

```
decrypted keychain head: b'bplist00'   ← valid binary plist
```

Keychain obtained: 4,439 `genp`, 460 `inet`, 563 `keys`, 12 `cert`.

---

## 6. Detour 4: Keychain Item GCM Decryption (Off-by-One Took Forever)

Each Keychain item's `v_Data` structure is:

```
version(4 LE)=3 | class(4 LE) | wrapped_key_len(4 LE)=40 | wrapped_key(40) | GCM ciphertext+tag
```

First attempt: unwrap the key, then use pycryptodome's AES-GCM (zero nonce) — **total failure**, not a single one of the 5,474 items decrypted.

Troubleshooting revealed a key phenomenon:

- Unwrapping `wrapped_key` succeeded for **classes 6/7/8** (auth passed), but failed for **9/10/11**.
- 9/10/11 are `…ThisDeviceOnly` classes, bound to the device key — **expected to be undecryptable in an encrypted backup** (expected, no solution).

So the key was correct, but **the GCM layer was wrong**. Zero nonce produced gibberish — the nonce was wrong.

Couldn't guess blindly anymore; had to find authoritative implementation. The source code of `dunhamsteve/ios` (a Go-based iOS backup extraction tool) gave the answer:

```go
// crypto/gcm/gcm.go, Open():
if len(nonce) != gcmNonceSize {
    // counter is all zeros for apple's blank iv
    // counter = [16]byte{0}      ← J0 = all-zero block
}
g.cipher.Encrypt(tagMask[:], counter[:])   // tagMask = E(0^16)
gcmInc32(&counter)                          // counter -> 0...0001
g.counterCrypt(out, ciphertext, &counter)   // data starts from counter=1
```

**Apple's "blank IV" GCM**: J0 = all-zero block (instead of the standard 12-byte nonce's `nonce||00000001`), and the data keystream starts from **counter=1**. This is **one counter block different** from pycryptodome's zero nonce.

Implemented with AES-CTR (prefix 12 zero bytes + 32-bit counter, **initial value 1**), and decrypted instantly:

```python
ctr = Counter.new(32, prefix=b"\x00"*12, initial_value=1)
plain = AES.new(key, AES.MODE_CTR, counter=ctr).decrypt(edata[:-16])
```

```
class7 plaintext head: b'1\x82\x02\xb40\x08\x0c\x04musr...'  ← DER-encoded keychain attributes
```

Reference: [dunhamsteve/ios](https://github.com/dunhamsteve/ios) · [xperylabhub/ios_keychain_decrypter](https://github.com/xperylabhub/ios_keychain_decrypter)

---

## 7. Parsing the Keychain, Searching for QQ's Database Key

The decrypted plaintext is **DER**: `SET OF SEQUENCE { UTF8String key, value }`, with fields like `musr/pdmn/svce/acct/agrp/v_Data` etc. Wrote a small DER parser (`kc.py`), scanned out 357 Tencent/QQ items.

### Detour 5: Thought I Found the Key, But It Wasn't

Examined every QQ access group (`com.tencent.mqq` / `com.tencent.generickeychain` / `com.tencent.ww`)'s 97 items, every exactly-32-character value, every item containing keywords like `db/cipher/kernel/nt_qq/yffm/...` — **none was the database key**.

However, when decoding some of QQ's NSKeyedArchiver blobs, one `com.tencent.mqq` item stored a 36-character token:

```
== com.tencent.mqq ==  '<redacted-token>'
```

It looked too much like a key. So I wrote a SQLCipher validator (using page HMAC as an oracle) to try it — **no match**. Tried various parameter combinations, still no match.

> Detour conclusion: this token is not the database key. And my modeling of the SQLCipher format might also be wrong.

---

## 8. Re-examining the File Structure + Key References

### 8.1 `nt_msg.db` Is Not "Salt at the Front" Standard SQLCipher

Re-examined the header: the first ~96 bytes are **plaintext metadata** (`QQ_NT DB`, `HMAC_SHA1` are directly readable), and from `0x4a` to the end of the first page it's **all zeros**.

```python
print(len(d)%1024, len(d)%4096)   # -> 0, 1024
```

File size is a multiple of 1024, but not a multiple of 4096 → **page size 1024?** Looked at offset **1024**:

```
<salt·redacted> cc97f803...
```

**These 16 bytes are exactly the same as the beginning of the `.material` files!** This is the **SQLCipher salt**.

The truth emerges: the file = **1024 bytes of plaintext QQ header** + a **standard SQLCipher database** (starting at offset 1024, salt + encrypted pages).

### 8.2 Reference: Mobile QQNT Key Derivation Formula

Desktop references (page=4096) didn't match the mobile version. Searched Android version (same `QQ_NT DB` format):

- [Android QQ NT Database Decryption - yllhwa](https://blog.yllhwa.com/blog/android_qq_nt_database/)
- [qq-win-db-key / Tutorial - NTQQ (Android).md](<https://github.com/QQBackup/qq-win-db-key/blob/master/%E6%95%99%E7%A8%8B%20-%20NTQQ%20(Android).md>)

`qq-win-db-key`'s Android tutorial gives the **exact formula**:

```
QQ_UID_hash = md5(uid)                              # uid looks like u_xxxxxxxx
QQ_path_hash = md5(md5(uid) + "nt_kernel")          # = nt_qq_ folder name
key          = md5(QQ_UID_hash + rand)              # 32-char lowercase hex, used as SQLCipher passphrase
```

Where `rand` = the readable string after the `QQ_NT DB` file header (for this db = `<rand·redacted>`).

SQLCipher parameters: **strip 1024-byte header**, `kdf_iter=4000`, `HMAC_SHA1`.

---

## 9. Finding the UID, Verifying, and Calculating the Key

The formula needs `uid`. Searched the container for `u_` tokens associated with the account:

```bash
grep -raoE 'u_[A-Za-z0-9_-]{22}' Container | sort | uniq -c | sort -rn
# Login-related plist/mmkv files repeatedly show u_<my-uid·redacted>
```

**Critical verification**: `md5(md5(uid)+"nt_kernel")` must equal the folder name `<path_hash·redacted>`. Tried candidate uids one by one:

```
*** MATCH uid=u_<my-uid·redacted> ***
    QQ_UID_hash = <md5-of-uid·redacted>
    DB key      = <db-key·redacted>
```

UID matched, key = **`<db-key·redacted>`**.

(With hindsight: the QQNT mobile database key is **not in the Keychain at all**; it's derived from the uid. But the Keychain detour wasn't entirely wasted — it helped me confirm the account's uid and login info, and the method itself is reusable.)

---

## 10. Verifying the Key + Full Decryption

### 10.1 Using Page HMAC as an Oracle

SQLCipher has `IV + HMAC` at the end of each page. If the key and parameters are correct, page-1's HMAC must match. `sqlcipher_try.py` brute-forced the parameter space:

```
MATCH key=ascii page_size=4096 kdf_iter=4000 kdf_prf=sha512 hmac=sha1 reserve=48
```

Note: **actual page_size is 4096** (the `0400` bytes in the header are misleading, falling in the overwritten metadata area). Final parameters:

> Strip 1024-byte header → standard SQLCipher: page=4096, kdf_iter=4000, KDF=PBKDF2-HMAC-**SHA512**, page HMAC=**SHA1**, AES-256-CBC, reserve=48.

### 10.2 Page-by-Page Decryption (`decrypt_db.py`)

- Salt = 16 bytes starting at offset 1024.
- `enc_key = PBKDF2-SHA512(passphrase, salt, 4000, 32)`
- `hmac_key = PBKDF2-SHA512(enc_key, salt⊕0x3a, 2, 32)`
- Each page: extract IV from page tail → AES-256-CBC decrypt page body; for page 1, prepend the standard `SQLite format 3\0` magic.

```
decrypted 55635 pages, hmac-mismatches=0 -> work/nt_msg.plain.db
=== header === SQLite format 3.
```

**55,635 pages, zero HMAC mismatches** — perfect decryption. Table structure appeared: `c2c_msg_table`, `group_msg_table`, `nt_uid_mapping_table` …

---

## 11. Finding the Conversation with <their-qq>

`nt_msg.db` uses numeric column names and uses uid (not uin) to identify people. `nt_uid_mapping_table` did **not** contain `<their-qq>`.

Grepped directly in the decrypted database:

```
&uin=<their-qq>&uid=u_<their-uid·redacted>
```

**<their-qq> = uid `u_<their-uid·redacted>`** — and it is exactly the top counterparty in `c2c_msg_table` by message count (24,341 messages)!

Column meanings figured out:

| Column  | Meaning                                                                     |
| ------- | --------------------------------------------------------------------------- |
| `40021` | Counterparty uid (conversation primary key, constant for the entire thread) |
| `40020` | Sender uid                                                                  |
| `40033` | Sender uin (true sender)                                                    |
| `40030` | **Counterparty uin (constant = <their-qq>, not the sender!)**               |
| `40050` | Unix timestamp                                                              |
| `40800` | Message elements (protobuf)                                                 |

### Detour 6: Wrong Direction Judgment

Initially used `40030` as the sender, causing my own messages to be mislabeled as "theirs". After cross-checking, found that `40030` is the constant counterparty number; the true sender is `40033` (or compare `40020`'s uid with my own uid). After correction: me 10,269 / them 13,652 / system 420.

---

## 12. Parsing Message Content (protobuf) + Exporting JSON

`40800` is the protobuf for message elements. Wrote a generic protobuf parser to recursively extract values, and located the text at **`element → 45101`**:

```
[40800.45101] '(example text message·redacted)'
```

Element types:

| Field           | Type                                                         |
| --------------- | ------------------------------------------------------------ |
| `45101`         | Text                                                         |
| `45402`         | Image (filename + md5)                                       |
| `45815 / 47602` | Sticker / large sticker description (`[动画表情]`, `[崇拜]`) |
| `49154`         | Market sticker                                               |
| `48271`         | Grey-bar system prompt (JSON)                                |
| `47402–47423`   | Quote/reply wrapper                                          |
| `47702–47704`   | File/video                                                   |
| `80800–80999`   | Ark card                                                     |

`export_json.py` exported all 24,341 messages, each containing `msg_id / seq / sender_uin / sender_uid / sender_name / is_me / time / time_str / text / elements`. Element category statistics:

```
text 17466, image 4898, reply 1055, face 854, marketface 821,
struct_card 301, ark_card 261, video 106, share 91, greytip 28,
poke_or_superface 546, file_or_video 30, unknown 6
```

Final sample, direction correct, reads naturally:

```
[2025-02-27 18:38:11] Them: (message content·redacted)
[2025-02-27 18:47:33] <my-nickname>: (message content·redacted)
[2025-02-27 18:47:58] Them: (message content·redacted)
```

---

## 13. Deliverables and Script List

| File                           | Description                                                               |
| ------------------------------ | ------------------------------------------------------------------------- |
| `chat_<my-qq>_<their-qq>.json` | Final chat history, 24,341 messages, ~11 MB                               |
| `work/nt_msg.plain.db`         | Fully decrypted plaintext SQLite (contains all conversations/group chats) |
| `work/keychain-backup.plist`   | Decrypted Keychain                                                        |
| `bk.py`                        | Decrypt iOS encrypted backup keybag + Manifest.db + Keychain file         |
| `kc.py`                        | Decrypt Keychain items (Apple blank-IV GCM) + DER parsing                 |
| `decrypt_db.py`                | QQNT database decryption (strip header + SQLCipher page-by-page)          |
| `sqlcipher_try.py`             | Verify key/parameters using page HMAC                                     |
| `export_json.py`               | Parse message table + protobuf, export JSON                               |

---

## 14. Retrospective: What Were Detours, What Were Keys

**Detours Taken**

1. Hoped the legacy `QQ.db` would work (plaintext but no match).
2. Tried to reverse-engineer the app binary (stripped).
3. Ransacked the container for the key (not in the container at all).
4. Used standard zero-nonce GCM for Keychain items (off-by-one counter block; Apple uses blank-IV).
5. Took a 36-character token from `com.tencent.mqq` as the key (it wasn't).
6. Assumed `nt_msg.db` was "salt at the front" standard SQLCipher (actually has a 1024-byte QQ header).
7. Used `40030` to judge message direction (it's the constant counterparty number; true sender is `40033`).

**Real Key Breakthroughs**

- Recognized that encrypted backup is the only way to get the Keychain without jailbreaking.
- Got Apple blank-IV GCM implementation details from `dunhamsteve/ios` source code.
- The 16 bytes at offset 1024 match the `.material` file → recognized the true SQLCipher salt and the 1024-byte header.
- Found the mobile `key = md5(md5(uid)+rand)` formula, and reverse-verified the uid using the folder hash `md5(md5(uid)+"nt_kernel")`.
- Used **page HMAC as a deterministic oracle** throughout, so "right/wrong" had a definitive answer instead of guessing by eye.

**One-sentence summary**: QQNT mobile `nt_msg.db` = `1024-byte plaintext header + standard SQLCipher(page=4096, kdf_iter=4000, PBKDF2-HMAC-SHA512, HMAC-SHA1, AES-256-CBC)`, passphrase = `md5(md5(uid) + header rand string)`. The uid can be found from device data and verified using the `nt_qq` folder hash.

---

## References

- [QQDecrypt: NTQQ Decrypt Database](https://qqbackup.github.io/QQDecrypt/decrypt/decode_db.html)
- [qq-win-db-key (All-Platform QQ Database Decryption)](https://github.com/QQBackup/qq-win-db-key) · [Android Tutorial](<https://github.com/QQBackup/qq-win-db-key/blob/master/%E6%95%99%E7%A8%8B%20-%20NTQQ%20(Android).md>)
- [Android QQ NT Database Decryption - yllhwa](https://blog.yllhwa.com/blog/android_qq_nt_database/)
- [Mythologyli/qq-nt-db](https://github.com/Mythologyli/qq-nt-db)
- [dunhamsteve/ios (iOS backup/keychain extraction, Go)](https://github.com/dunhamsteve/ios)
- [xperylabhub/ios_keychain_decrypter](https://github.com/xperylabhub/ios_keychain_decrypter)
- [ElcomSoft: Extracting and Decrypting iOS Keychain](https://blog.elcomsoft.com/2020/08/extracting-and-decrypting-ios-keychain-physical-logical-and-cloud-options-explored/)
- [Hakuuyosei/QQHistoryExport](https://github.com/Hakuuyosei/QQHistoryExport)

---

_This article documents a forensic-style export of the author's own account and own device data, for personal chat history backup purposes._
