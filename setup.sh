#!/bin/bash
# setup.sh — install dependencies and build static libraries for hashpipe
# Usage: ./setup.sh         # install/build all dependencies
#        ./setup.sh clean   # remove all generated artifacts

set -e

PROJ="$(cd "$(dirname "$0")" && pwd)"

# Pinned commit SHAs for supply-chain safety
SPHLIB_REPO=https://github.com/pornin/sphlib.git
SPHLIB_SHA=15b6b8d8f3e4a43c58ba102d712fa6b8a3317035

RETTER_REPO=https://github.com/brandondahler/retter.git
RETTER_SHA=eaba612ef34c35ac6cce6a1778e91908ec62bd0e

STREEBOG_REPO=https://github.com/adegtyarev/streebog.git
STREEBOG_SHA=62e2120042fae0bb19381a8acb1b8dc425b761f7

BCRYPT_REPO=https://github.com/openwall/crypt_blowfish.git
BCRYPT_SHA=3354bb81eea489e972b0a7c63231514ab34f73a0

YESCRYPT_REPO=https://github.com/openwall/yescrypt.git
YESCRYPT_SHA=62ee1f0611b0c0b28db459235914d1ab5c280cb6

if [ "$1" = "clean" ]; then
    echo "==> Cleaning generated artifacts..."
    rm -f "$PROJ"/sph_*.h "$PROJ"/sph_types.h
    rm -f "$PROJ"/libsph.a "$PROJ"/md6.a "$PROJ"/md6.h
    rm -f "$PROJ"/libssl.a "$PROJ"/libcrypto.a "$PROJ"/libmhash.a "$PROJ"/librhash.a "$PROJ"/libJudy.a
    rm -rf "$PROJ"/gosthash "$PROJ"/bcrypt-master "$PROJ"/yescrypt
    echo "    Done."
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}/hashpipe-deps-$$"
mkdir -p "$TMPDIR"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Clone a repo and checkout a pinned commit
pinned_clone() {
    local repo=$1 sha=$2 dest=$3
    git clone --depth 64 "$repo" "$dest"
    cd "$dest"
    if ! git cat-file -e "$sha" 2>/dev/null; then
        git fetch --depth 256 origin
    fi
    git checkout "$sha"
    cd "$PROJ"
}

echo "==> Installing system packages..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq build-essential libssl-dev libmhash-dev \
        librhash-dev libjudy-dev zlib1g-dev git
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y gcc make openssl-devel mhash-devel librhash-devel \
        Judy-devel zlib-devel git
elif command -v brew >/dev/null 2>&1; then
    brew install openssl libmhash rhash judy
else
    echo "Unsupported package manager. Install manually:"
    echo "  OpenSSL (dev), libmhash (dev), librhash (dev), libJudy (dev), zlib (dev), git"
    exit 1
fi

# ---- sphlib ----
if [ ! -f "$PROJ/libsph.a" ]; then
    echo "==> Building sphlib ($SPHLIB_SHA)..."
    pinned_clone "$SPHLIB_REPO" "$SPHLIB_SHA" "$TMPDIR/sphlib"
    cd "$TMPDIR/sphlib/c"
    SPH_SRCS=$(ls *.c | grep -v '^test_' | grep -v '^hsum' | grep -v '^speed' \
        | grep -v 'sha3nist' | grep -v '^utest' | grep -v '_helper\.c')
    cc -O3 -Wno-unused-function -c $SPH_SRCS
    ar rcs libsph.a *.o
    cp libsph.a "$PROJ/"
    cp sph_*.h "$PROJ/"
    echo "    libsph.a built"
else
    echo "==> libsph.a already exists, skipping"
fi

# ---- md6 ----
if [ ! -f "$PROJ/md6.a" ]; then
    echo "==> Building md6 ($RETTER_SHA)..."
    pinned_clone "$RETTER_REPO" "$RETTER_SHA" "$TMPDIR/retter"
    cd "$TMPDIR/retter/MD6"
    cc -O3 -fcommon -c md6_compress.c md6_mode.c
    ar rcs md6.a md6_compress.o md6_mode.o
    cp md6.a "$PROJ/"
    cp md6.h "$PROJ/"
    echo "    md6.a built"
else
    echo "==> md6.a already exists, skipping"
fi

# ---- GOST R 34.11-2012 (Streebog) ----
if [ ! -f "$PROJ/gosthash/gost2012/gost2012.a" ]; then
    echo "==> Building gost2012 ($STREEBOG_SHA)..."
    pinned_clone "$STREEBOG_REPO" "$STREEBOG_SHA" "$TMPDIR/streebog"
    cd "$TMPDIR/streebog"
    # Generate config header inline (replaces bash configure from upstream)
    cat > gost3411-2012-config.h << 'CONFEOF'
#ifndef __GOST3411_LITTLE_ENDIAN__
#define __GOST3411_LITTLE_ENDIAN__
#endif
CONFEOF
    SSE_FLAG=""
    if grep -q 'sse4_1\|sse4\.1' /proc/cpuinfo 2>/dev/null; then
        SSE_FLAG="-msse4.1"
        printf '#ifndef __GOST3411_HAS_SSE41__\n#define __GOST3411_HAS_SSE41__\n#endif\n' >> gost3411-2012-config.h
    fi
    if grep -q 'sse2' /proc/cpuinfo 2>/dev/null; then
        printf '#ifndef __GOST3411_HAS_SSE2__\n#define __GOST3411_HAS_SSE2__\n#endif\n' >> gost3411-2012-config.h
    fi
    if grep -q 'mmx' /proc/cpuinfo 2>/dev/null; then
        printf '#ifndef __GOST3411_HAS_MMX__\n#define __GOST3411_HAS_MMX__\n#endif\n' >> gost3411-2012-config.h
    fi
    cc -O3 -fcommon $SSE_FLAG -c gost3411-2012-core.c
    ar rcs gost2012.a gost3411-2012-core.o
    mkdir -p "$PROJ/gosthash/gost2012"
    cp gost2012.a "$PROJ/gosthash/gost2012/"
    cp gost3411-2012-core.h gost3411-2012-const.h gost3411-2012-precalc.h \
       gost3411-2012-ref.h gost3411-2012-config.h "$PROJ/gosthash/gost2012/"
    for f in gost3411-2012-sse2.h gost3411-2012-sse41.h gost3411-2012-mmx.h; do
        [ -f "$f" ] && cp "$f" "$PROJ/gosthash/gost2012/"
    done
    echo "    gost2012.a built"
else
    echo "==> gost2012.a already exists, skipping"
fi

# Create streebog.h wrapper if missing
if [ ! -f "$PROJ/gosthash/gost2012/streebog.h" ]; then
    cat > "$PROJ/gosthash/gost2012/streebog.h" << 'WRAPPER'
/* streebog.h — thin wrapper mapping streebog_*() API to GOST34112012*() */
#ifndef STREEBOG_H
#define STREEBOG_H
#include "gost3411-2012-core.h"
typedef GOST34112012Context streebog_t;
static inline void streebog_init(streebog_t *ctx, unsigned int digest_bytes) {
    GOST34112012Init(ctx, digest_bytes * 8);
}
static inline void streebog_update(streebog_t *ctx, const void *data, size_t len) {
    GOST34112012Update(ctx, (const unsigned char *)data, len);
}
static inline void streebog_final(unsigned char *digest, streebog_t *ctx) {
    GOST34112012Final(ctx, digest);
}
static inline void streebog(unsigned char *digest, unsigned int digest_bytes,
                             const void *data, size_t len) {
    streebog_t ctx;
    streebog_init(&ctx, digest_bytes);
    streebog_update(&ctx, data, len);
    streebog_final(digest, &ctx);
}
#endif
WRAPPER
    echo "    streebog.h wrapper created"
fi

# ---- bcrypt (Openwall crypt_blowfish) ----
if [ ! -f "$PROJ/bcrypt-master/bcrypt.a" ]; then
    echo "==> Building bcrypt ($BCRYPT_SHA)..."
    pinned_clone "$BCRYPT_REPO" "$BCRYPT_SHA" "$TMPDIR/bcrypt"
    cd "$TMPDIR/bcrypt"
    cc -O3 -c crypt_blowfish.c wrapper.c crypt_gensalt.c
    ar rcs bcrypt.a crypt_blowfish.o wrapper.o crypt_gensalt.o
    mkdir -p "$PROJ/bcrypt-master"
    cp bcrypt.a "$PROJ/bcrypt-master/"
    echo "    bcrypt.a built"
else
    echo "==> bcrypt.a already exists, skipping"
fi

# ---- yescrypt (Openwall, provides crypto_scrypt) ----
if [ ! -f "$PROJ/yescrypt/yescrypt.a" ]; then
    echo "==> Building yescrypt ($YESCRYPT_SHA)..."
    pinned_clone "$YESCRYPT_REPO" "$YESCRYPT_SHA" "$TMPDIR/yescrypt"
    cd "$TMPDIR/yescrypt"
    cc -O3 -c yescrypt-opt.c yescrypt-common.c sha256.c insecure_memzero.c
    ar rcs yescrypt.a yescrypt-opt.o yescrypt-common.o sha256.o insecure_memzero.o
    mkdir -p "$PROJ/yescrypt"
    cp yescrypt.a "$PROJ/yescrypt/"
    cp yescrypt.h "$PROJ/yescrypt/"
    echo "    yescrypt.a built"
else
    echo "==> yescrypt.a already exists, skipping"
fi

# ---- Symlink system static libraries (Linux only) ----
if [ "$(uname -s)" != "Darwin" ]; then
    echo "==> Creating symlinks for system static libraries..."
    LIBDIR=$(pkg-config --variable=libdir openssl 2>/dev/null || echo "/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)")
    for lib in libssl.a libcrypto.a libmhash.a librhash.a libJudy.a; do
        if [ -f "$LIBDIR/$lib" ] && [ ! -f "$PROJ/$lib" ]; then
            ln -sf "$LIBDIR/$lib" "$PROJ/$lib"
        fi
    done
fi

echo ""
echo "==> All dependencies ready. Build with:"
echo "    make hashpipe"
