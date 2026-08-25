||| Clone Gate CLI — sovereign integrity enforcement in Idris 2.
|||
||| Usage:
|||   clone_gate seal    -- hash all registered modules, write MANIFEST.seal
|||   clone_gate verify  -- verify all modules against manifest
|||   clone_gate status  -- print per-file seal status
|||
||| Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica)
||| License: BSL-1.1 / AGPL-3.0 / MPL-2.0
||| Author: Ahmad Ali Parr
||| Linear types: WORM chain is append-only by construction (WORM.idr)
||| Dependent types: Chain n tracks entry count at compile time
module Main

import Data.String
import System
import System.Directory
import Manifest
import WORM
import Hash

-- ── Entry point ────────────────────────────────────────────────────────────

main : IO ()
main = do
  args    <- getArgs
  repoRoot <- case !currentDir of
                Right d => pure d
                Left  _ => pure "."
  case args of
    [_, "seal"] => do
      putStrLn "\n[clone_gate] Sealing all registered modules...\n"
      n <- sealAll repoRoot
      putStrLn $ "\n[clone_gate] Chain length : " ++ show n ++ " entries"
      putStrLn   "[clone_gate] Seal complete."

    [_, "verify"] => do
      putStrLn "\n[clone_gate] Verifying all registered modules...\n"
      ok <- verifyAll repoRoot
      if ok
        then do
          putStrLn "\n[clone_gate] All modules verified — chain intact."
          exitSuccess
        else do
          putStrLn "\n[clone_gate] VERIFICATION FAILED — chain integrity violated."
          exitFailure

    [_, "status"] => do
      putStrLn "\n[clone_gate] Seal status:\n"
      _ <- verifyAll repoRoot
      pure ()

    _ => putStrLn """
[clone_gate] Reverse Quantum Walk — Sovereign Clone Gate (Idris 2)

Usage:
  clone_gate seal     Hash all registered modules, write MANIFEST.seal
  clone_gate verify   Verify all modules against MANIFEST.seal
  clone_gate status   Print per-file status

Linear types enforce append-only WORM invariant at compile time.
Dependent types track chain entry count: Chain n.
SHA-256 via OpenSSL (cbits/hash_shim.c).

Build:
  idris2 --build clone_gate.ipkg
Run:
  ./build/exec/clone_gate seal
"""
