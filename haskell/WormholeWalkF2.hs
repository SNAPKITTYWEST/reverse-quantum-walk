{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -Wall #-}
-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Wormhole Walk over 𝔽₂ — bit-packed Word64, 128× memory compression
-- Corresponds to Lean: lean/WalkAA/WormholeWalk.lean
--   wormholeWalk_involution (ZERO SORRY)
--
-- W_ER(ψ)(i) = ψ(i) XOR dmzParity(ψ)  — 𝔽₂ affine shift
-- dmzParity = popCount of all bits mod 2 (global Hecke eigenvalue mod 2)
-- 64 microstates per Word64 → 2^30 states in ~134 MB (vs 8 GB complex)
--
-- Build: ghc -O2 -fllvm -threaded -rtsopts WormholeWalkF2.hs -o wormholeWalkF2
-- Run:   ./wormholeWalkF2
-- ============================================================

module Main where

import Data.Word (Word64)
import Data.Bits (popCount, xor)
import qualified Data.Vector.Unboxed as VU
import Control.Parallel.Strategies
import System.Time.It (timeIt)

type F2Bulk = VU.Vector Word64

-- | DMZ projection parity: sum of all set bits mod 2
--   Corresponds to Lean: DMZ_Projection state = Σᵢ state(i) in ZMod 2
dmzParity :: F2Bulk -> Word64
dmzParity bulk =
  let totalBits = VU.foldl' (\acc w -> acc + popCount w) 0 bulk
  in if even totalBits then 0 else maxBound  -- 0x00..00 or 0xFF..FF

-- | Wormhole Walk W_ER over 𝔽₂ with parallel chunks
--   w XOR globalMask  ≡  each microstate XOR DMZ parity
--   Involution: applying twice = identity (XOR is self-inverse)
wormholeWalkF2 :: F2Bulk -> Int -> F2Bulk
wormholeWalkF2 bulk numChunks =
  let n          = VU.length bulk
      chunkSize  = n `div` numChunks
      bounds     = [ (off, min n (off + chunkSize))
                   | off <- [0, chunkSize .. n - 1] ]
      !mask      = dmzParity bulk  -- evaluated once, shared across chunks
      buildChunk (s, e) =
        VU.generate (e - s) $ \i ->
          VU.unsafeIndex bulk (s + i) `xor` mask
      chunks = map buildChunk bounds `using` parList rseq
  in VU.concat chunks

main :: IO ()
main = do
  -- 2^30 microstates bit-packed into 2^30/64 = 2^24 Word64s
  -- Memory: 2^24 * 8 bytes = 128 MB  (vs 2^30 * 16 bytes = 16 GB for complex)
  let totalStates = 2 ^ (30 :: Int)
      numWords    = totalStates `div` 64
      -- Alternating pattern 0xAAAA... (half bits set) for interesting parity
      vec = VU.replicate numWords (0xAAAAAAAAAAAAAAAA :: Word64)
  putStrLn $ "Wormhole Walk over 𝔽₂: "
          ++ show totalStates ++ " microstates bit-packed into "
          ++ show numWords ++ " Word64s (~"
          ++ show (numWords * 8 `div` (1024*1024)) ++ " MB)"
  timeIt $ do
    let !out = wormholeWalkF2 vec 32
    putStrLn $ "Walk complete. First Word64: 0x"
            ++ showHex64 (VU.unsafeIndex out 0)
    -- Verify involution: apply twice should return original
    let !out2 = wormholeWalkF2 out 32
    putStrLn $ "Involution check (should match input): "
            ++ show (out2 == vec)

showHex64 :: Word64 -> String
showHex64 w = foldr (\n acc -> hexChar n : acc) ""
  [ (fromIntegral w `div` (16^i)) `mod` 16 | i <- [15,14..0::Int] ]
  where
    hexChar n | n < 10    = toEnum (fromEnum '0' + n)
              | otherwise = toEnum (fromEnum 'a' + n - 10)
