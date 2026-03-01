<p align="center">
  <img src="img/hashpipe.svg" width="128" alt="hashpipe logo">
</p>

# hashpipe

Multi-threaded hash verification tool. Reads lines containing `hash:password` pairs (optionally with TYPE hints and salts), verifies them by computing the hash from the password, and outputs verified results in mdxfind stdout format. Unresolved lines go to stderr.

Uses [yarn.c](https://github.com/madler/pigz) for threading and OpenSSL for hash computation.

## Supported Hash Types

| Type | Algorithm | MDXfind | hashcat |
|------|-----------|---------|---------|
| MD5 | `md5($pass)` | e1 | -m 0 |
| MD5UC | `md5($pass)` (uppercase hex) | e1 | -m 0 |
| MD4 | `md4($pass)` | e3 | -m 900 |
| NTLM | `md4(utf16le($pass))` | e369 | -m 1000 |
| SHA1 | `sha1($pass)` | e8 | -m 100 |
| SHA1UC | `sha1($pass)` (uppercase hex) | e8 | -m 100 |
| SHA224 | `sha224($pass)` | e9 | -m 1300 |
| SHA256 | `sha256($pass)` | e10 | -m 1400 |
| SHA384 | `sha384($pass)` | e11 | -m 10800 |
| SHA512 | `sha512($pass)` | e12 | -m 1700 |
| MD5PASSSALT | `md5($pass.$salt)` | e373 | -m 10 |
| MD5SALT | `md5(hex(md5($pass)).$salt)` | e31 | -m 2611 |
| SHA1SALTPASS | `sha1($salt.$pass)` | e385 | -m 120 |
| SHA1PASSSALT | `sha1($pass.$salt)` | e405 | -m 110 |
| SHA256SALTPASS | `sha256($salt.$pass)` | e412 | -m 1420 |
| SHA256PASSSALT | `sha256($pass.$salt)` | e413 | -m 1410 |
| SHA512SALTPASS | `sha512($salt.$pass)` | e388 | -m 1720 |
| SHA512PASSSALT | `sha512($pass.$salt)` | e386 | -m 1710 |
| MD5MD5PASS | `md5(hex(md5($pass)).$pass)` | e123 | — |
| MD5MD5PASS | `md5(hex(md5($pass)).":".$pass)` | e123 | — |
| SHA1MD5 | `sha1(hex(md5($pass)))` | e160 | -m 4700 |
| MD5SHA1 | `md5(hex(sha1($pass)))` | e178 | -m 4400 |

## Building

```
make
```

Requires OpenSSL development libraries.

## License

MIT
