||| Manifest.seal read/write and per-file gate verification.
|||
||| Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica)
||| License: BSL-1.1 / AGPL-3.0 / MPL-2.0
module Manifest

import Data.String
import Data.List
import Data.Maybe
import System.File
import System.File.ReadWrite
import Hash
import WORM

-- ── Registered modules ─────────────────────────────────────────────────────

||| Every file the clone gate tracks.
||| All zeros = UNSEALED. Run `clone_gate seal` to populate.
export
registeredModules : List String
registeredModules =
  [ "clone_gate/src/Hash.idr"
  , "clone_gate/src/WORM.idr"
  , "clone_gate/src/Manifest.idr"
  , "clone_gate/src/Main.idr"
  , "clone_gate/cbits/hash_shim.c"
  , "crates/engine/src/recurrence.rs"
  , "crates/engine/src/microbit.rs"
  , "crates/engine/src/cad_kernel.rs"
  , "crates/engine/src/icp_model.rs"
  , "crates/engine/src/mmep_relaxation.rs"
  , "crates/kani-verification/src/lib.rs"
  , "crates/kani-verification/src/arithmetic_loop.rs"
  , "lean/Multiplicity/Dynamics/Contraction.lean"
  , "lean/Multiplicity/Dynamics/GTHZHarmony.lean"
  , "lean/WalkAA/WalkAmplitudeAmplification.lean"
  , "lean/WalkAA/WormholeWalk.lean"
  , "agda/MultiplicityInvariants.agda"
  , "agda/PrimitiveShattering.agda"
  , "agda/GTHZHarmony.agda"
  , "haskell/JohnsonWalk.hs"
  , "haskell/JohnsonWalkStorable.hs"
  , "haskell/JohnsonWalkParallel.hs"
  , "haskell/WormholeWalkF2.hs"
  , "circuits/MicrobitFullAdder.circom"
  , "circuits/MicrobitAdderAndDrift.circom"
  , "hardware/microbit_interlock.sv"
  , "tools/f2_solver.py"
  ]

-- ── MANIFEST.seal path ─────────────────────────────────────────────────────

export
manifestPath : String
manifestPath = "MANIFEST.seal"

-- ── Seal all registered modules ────────────────────────────────────────────

||| Hash every registered module and write MANIFEST.seal.
||| Returns the number of entries sealed.
export
sealAll : HasIO io => String -> io Nat
sealAll repoRoot = do
  let go : (1 c : Chain n) -> List String -> io (n : Nat ** Chain n)
      go c [] = pure (_ ** c)
      go c (rel :: rest) = do
        let abs = repoRoot ++ "/" ++ rel
        let lbl = "module:" ++ rel
        c' <- sealFile c lbl rel abs
        go c' rest
  (_ ** chain) <- go Empty registeredModules
  let entries  = toList chain
  let jsonl    = unlines (map entryToJsonl entries)
  Right _ <- writeFile manifestPath jsonl
    | Left err => do
        putStrLn $ "[clone_gate] ERROR writing " ++ manifestPath ++ ": " ++ show err
        pure 0
  putStrLn $ "[clone_gate] Sealed " ++ show (length entries) ++ " modules -> " ++ manifestPath
  pure (length entries)

-- ── Parse MANIFEST.seal ────────────────────────────────────────────────────

-- Minimal JSON field extractor (no external JSON library needed)
extractField : String -> String -> Maybe String
extractField key line =
  let needle = "\"" ++ key ++ "\":\""
  in case strIndex line (cast (length needle)) of
    _ => case split (== needle) line of
      [_, rest] => Just (takeWhile (/= '"') rest)
      _         => Nothing

parseEntry : String -> Maybe Entry
parseEntry line = do
  label  <- extractField "label"  line
  path   <- extractField "path"   line
  digest <- extractField "digest" line
  prev   <- extractField "prev"   line
  seal   <- extractField "seal"   line
  pure $ MkEntry label path digest prev seal

-- ── Verify all registered modules ──────────────────────────────────────────

data VerifyResult = OK String | Fail String String String | Missing String

export
verifyAll : HasIO io => String -> io Bool
verifyAll repoRoot = do
  Right contents <- readFile manifestPath
    | Left _ => do
        putStrLn "[clone_gate] MANIFEST.seal not found. Run: clone_gate seal"
        pure False
  let sealed : List Entry
      sealed = mapMaybe parseEntry (lines contents)
  let sealedMap : List (String, Entry)
      sealedMap = map (\e => (e.path, e)) sealed
  results <- traverse (checkOne repoRoot sealedMap) registeredModules
  let ok = all isOk results
  traverse_ printResult results
  pure ok
  where
    isOk : VerifyResult -> Bool
    isOk (OK _) = True
    isOk _      = False

    checkOne : HasIO io => String -> List (String, Entry) -> String -> io VerifyResult
    checkOne root sealedMap rel =
      case lookup rel sealedMap of
        Nothing => pure (Missing rel)
        Just e  => do
          actual <- sha256File (root ++ "/" ++ rel)
          if actual == e.digest
            then pure (OK rel)
            else pure (Fail rel e.digest actual)

    printResult : HasIO io => VerifyResult -> io ()
    printResult (OK rel)          = putStrLn $ "  [OK]      " ++ rel
    printResult (Missing rel)     = putStrLn $ "  [MISSING] " ++ rel
    printResult (Fail rel exp act) = do
      putStrLn $ "  [FAIL]    " ++ rel
      putStrLn $ "            expected: " ++ take 32 exp ++ "..."
      putStrLn $ "            actual  : " ++ take 32 act ++ "..."

-- ── Per-file gate (import-time check) ──────────────────────────────────────

||| Call at the top of any sovereign module to verify it hasn't been tampered.
||| On failure: prints an error and exits with code 1.
export
gate : HasIO io => String -> String -> io ()
gate repoRoot relPath = do
  Right contents <- readFile (repoRoot ++ "/" ++ manifestPath)
    | Left _ => do
        putStrLn $ "[clone_gate] WARNING: " ++ relPath ++ " — MANIFEST.seal not found (unsealed)"
        pure ()
  let sealed = mapMaybe parseEntry (lines contents)
  case find (\e => e.path == relPath) sealed of
    Nothing => putStrLn $ "[clone_gate] WARNING: " ++ relPath ++ " not in manifest"
    Just e  =>
      if isUnsealed e.digest
        then putStrLn $ "[clone_gate] WARNING: " ++ relPath ++ " UNSEALED"
        else do
          actual <- sha256File (repoRoot ++ "/" ++ relPath)
          when (actual /= e.digest) $ do
            putStrLn $ "\n[clone_gate] INTEGRITY FAILURE: " ++ relPath
            putStrLn $  "  expected: " ++ e.digest
            putStrLn $  "  actual  : " ++ actual
            putStrLn $  "  => File modified since last seal. Run: clone_gate seal"
            exitFailure
