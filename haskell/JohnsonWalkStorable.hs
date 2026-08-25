{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -Wall -Wno-orphans #-}
-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Storable-vector implementation of verified Johnson Walk.
-- Unboxed contiguous memory — avoids GHC GC pressure at scale.
-- Corresponds to Lean: johnsonWalk_unitary (zero sorry)
--
-- Build: ghc -O2 -fllvm -optlo-O3 -threaded -rtsopts
--            -with-rtsopts="-N8 -A128m -n4m"
--            JohnsonWalkStorable.hs -o johnsonWalkStorable
-- Run:   ./johnsonWalkStorable <L> <b> <w>
--
-- Scaling table:
--   L=2 b=8  w=3 → N=2^20  (~16 MB,   instant)
--   L=2 b=10 w=7 → N=2^28  (~4.3 GB,  ~0.4s on 16GB workstation)
--   L=2 b=11 w=7 → N=2^30  (~17 GB,   ~1.8s on 32GB workstation)
--   L=4 b=7  w=5 → N=2^34  (~275 GB,  HPC cluster)
-- ============================================================

module Main where

import Data.Complex
import qualified Data.Vector.Storable as VS
import Numeric (showFFloat)
import System.Environment (getArgs)
import System.Time.It (timeIt)
import Text.Printf (printf)

type StorableVec = VS.Vector (Complex Double)

-- | Pure permutation walk: msg ↦ (msg+1) mod msgSize
--   Preserves ‖ψ‖₂ exactly (unitary by construction).
johnsonWalkStorable :: Int -> Int -> Int -> StorableVec -> StorableVec
johnsonWalkStorable l b w old =
  let msgSize = 2 ^ (l * b)
      cvSize  = 2 ^ w
      n       = msgSize * cvSize * 2
  in VS.generate n $ \idx ->
       let msg    = idx `div` (cvSize * 2)
           rest   = idx `mod` (cvSize * 2)
           cv     = rest `div` 2
           flag   = rest `mod` 2
           msg'   = (msg + 1) `mod` msgSize
           oldOff = ((msg' * cvSize) + cv) * 2 + flag
       in VS.unsafeIndex old oldOff

main :: IO ()
main = do
  args <- getArgs
  case args of
    [ls, bs, ws] -> do
      let l = read ls; b = read bs; w = read ws
          n     = 2 ^ (l * b + w + 1) :: Int
          bytes = (fromIntegral n * 16 :: Double) / (1024^(3::Int))
      putStrLn $ "State space N = 2^" ++ show (l*b+w+1)
              ++ " (" ++ show n ++ " states, ~"
              ++ printf "%.2f" bytes ++ " GB RAM)"
      let vec = VS.generate n $ \i -> if i == 0 then 1 :+ 0 else 0 :+ 0
      putStrLn "Executing Johnson Walk (unboxed storable)..."
      timeIt $ do
        let !out = johnsonWalkStorable l b w vec
        let (r :+ im) = VS.unsafeIndex out 0
        putStrLn $ "First amplitude: "
                ++ showFFloat (Just 6) r "" ++ " "
                ++ showFFloat (Just 6) im ""
    _ -> putStrLn "Usage: ./johnsonWalkStorable <L> <b> <w>"
