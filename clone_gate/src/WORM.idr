||| WORM (Write-Once-Read-Many) append-only chain with linear types.
|||
||| Linear types enforce the invariant at compile time:
|||   - A Chain can only be EXTENDED, never mutated.
|||   - Once a seal is issued it cannot be retracted.
|||   - Reading the chain consumes it (you must use it exactly once).
|||
||| Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica)
||| License: BSL-1.1 / AGPL-3.0 / MPL-2.0
module WORM

import Data.String
import Hash

-- ── Entry ──────────────────────────────────────────────────────────────────

||| A single WORM chain entry.
public export
record Entry where
  constructor MkEntry
  label  : String   -- human-readable label (e.g. "module:src/Hash.idr")
  path   : String   -- repo-relative file path
  digest : String   -- SHA-256 of the file
  prev   : String   -- SHA-256 seal of the previous entry (or zeroDigest)
  seal   : String   -- SHA-256 of (label ++ path ++ digest ++ prev)

||| Serialise an entry to a single JSON line for MANIFEST.seal.
export
entryToJsonl : Entry -> String
entryToJsonl e =
  "{\"label\":\"" ++ e.label ++ "\","  ++
  "\"path\":\""   ++ e.path  ++ "\","  ++
  "\"digest\":\""  ++ e.digest ++ "\"," ++
  "\"prev\":\""   ++ e.prev  ++ "\","  ++
  "\"seal\":\""   ++ e.seal  ++ "\"}"

-- ── Chain (linear, append-only) ────────────────────────────────────────────

||| Append-only chain. The nat index tracks the entry count.
||| Linear (1 chain) means the old chain is consumed on append.
public export
data Chain : (n : Nat) -> Type where
  Empty : Chain 0
  Snoc  : (1 c : Chain n) -> Entry -> Chain (S n)

||| Append an entry. Linearly consumes the old chain.
export
append : (1 c : Chain n) -> Entry -> Chain (S n)
append c e = Snoc c e

||| Flatten the chain to a list of entries (oldest first).
||| Consumes the chain linearly.
export
toList : (1 c : Chain n) -> List Entry
toList Empty      = []
toList (Snoc c e) = toList c ++ [e]

||| The seal of the last entry, or zeroDigest for an empty chain.
export
lastSeal : (1 c : Chain n) -> (String, Chain n)
lastSeal Empty        = (Hash.zeroDigest, Empty)
lastSeal (Snoc c e)   =
  let (_, c') = lastSeal c   -- consume inner chain
  in  (e.seal, Snoc c' e)

-- ── Construction helpers ────────────────────────────────────────────────────

||| Build a new Entry, computing its seal from the C FFI.
export
mkEntry : HasIO io => String -> String -> String -> String -> io Entry
mkEntry label path digest prev = do
  let raw = label ++ path ++ digest ++ prev
  seal <- sha256String raw
  pure $ MkEntry label path digest prev seal

||| Build an Entry from a file path, computing its file digest.
export
sealFile : HasIO io
        => (1 c : Chain n)
        -> String        -- label
        -> String        -- repo-relative path
        -> String        -- absolute path (for hashing)
        -> io (Chain (S n))
sealFile c label relPath absPath = do
  digest <- sha256File absPath
  let (prev, c') = lastSeal c
  e <- mkEntry label relPath digest prev
  pure (append c' e)
