/*
 * PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
 * Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
 * SHA-256 C shim for Idris 2 FFI.
 * Links against OpenSSL libcrypto.
 */

#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Read a file and return its SHA-256 digest as a 64-char hex string.
 * Caller must free the returned string.
 * Returns NULL on error.
 */
char* idris2_sha256_file(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;

    SHA256_CTX ctx;
    SHA256_Init(&ctx);

    unsigned char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        SHA256_Update(&ctx, buf, n);
    }
    fclose(f);

    unsigned char digest[SHA256_DIGEST_LENGTH];
    SHA256_Final(digest, &ctx);

    char* hex = malloc(65);
    if (!hex) return NULL;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(hex + i * 2, "%02x", digest[i]);
    }
    hex[64] = '\0';
    return hex;
}

/*
 * SHA-256 of a raw string (for sealing entry metadata).
 * Caller must free the returned string.
 */
char* idris2_sha256_string(const char* s) {
    SHA256_CTX ctx;
    SHA256_Init(&ctx);
    SHA256_Update(&ctx, s, strlen(s));

    unsigned char digest[SHA256_DIGEST_LENGTH];
    SHA256_Final(digest, &ctx);

    char* hex = malloc(65);
    if (!hex) return NULL;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(hex + i * 2, "%02x", digest[i]);
    }
    hex[64] = '\0';
    return hex;
}
