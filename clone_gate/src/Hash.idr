||| SHA-256 via C FFI (OpenSSL libcrypto)
|||
||| Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica)
||| License: BSL-1.1 / AGPL-3.0 / MPL-2.0
module Hash

-- ── C FFI ──────────────────────────────────────────────────────────────────

%foreign "C:idris2_sha256_file,clone_gate_hash"
prim__sha256File : String -> PrimIO String

%foreign "C:idris2_sha256_string,clone_gate_hash"
prim__sha256String : String -> PrimIO String

-- ── Public API ─────────────────────────────────────────────────────────────

||| SHA-256 of a file's byte content. Returns 64-char lowercase hex.
export
sha256File : HasIO io => String -> io String
sha256File path = primIO (prim__sha256File path)

||| SHA-256 of a raw string. Returns 64-char lowercase hex.
export
sha256String : HasIO io => String -> io String
sha256String s = primIO (prim__sha256String s)

||| The zero digest (unsealed sentinel).
export
zeroDigest : String
zeroDigest = replicate 64 '0'

||| True if a digest is the unsealed zero sentinel.
export
isUnsealed : String -> Bool
isUnsealed d = d == zeroDigest
