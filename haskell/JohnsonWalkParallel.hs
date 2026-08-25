{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wall -Wno-orphans #-}
-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Parallel chunked Johnson Walk — parList rseq + VS.concat
-- Corresponds to Lean: johnsonWalk_unitary (zero sorry)
--
-- Build: ghc -O2 -fllvm -threaded -rtsopts
--            -with-rtsopts="-N"
--            JohnsonWalkParallel.hs -o johnsonWalkParallel
-- Run:   ./johnsonWalkParallel <L> <b> <w> <num_chunks> +RTS -N16 -s
-- ============================================================

module Main where

import Data.Complex
import qualified Data.Vector.Storable as VS
import Control.Parallel.Strategies
import System.Environment (getArgs)
import System.Time.It (timeIt)
import Text.Printf (printf)

type StorableVec = VS.Vector (Complex Double)

-- | Parallel Johnson Walk: splits into numChunks blocks, each chunk
--   generated independently on a sparked thread, then concatenated.
johnsonWalkParallel :: Int -> Int -> Int -> StorableVec -> Int -> StorableVec
johnsonWalkParallel l b w old numChunks =
  let msgSize   = 2 ^ (l * b)
      cvSize    = 2 ^ w
      n         = msgSize * cvSize * 2
      chunkSize = n `div` numChunks
      bounds    = [ (off, min n (off + chunkSize))
                  | off <- [0, chunkSize .. n - 1] ]

      buildChunk (s, e) =
        VS.generate (e - s) $ \i ->
          let idx    = s + i
              msg    = idx `div` (cvSize * 2)
              rest   = idx `mod` (cvSize * 2)
              cv     = rest `div` 2
              flag   = rest `mod` 2
              msg'   = (msg + 1) `mod` msgSize
              oldOff = ((msg' * cvSize) + cv) * 2 + flag
          in VS.unsafeIndex old oldOff

      -- parList rseq: spark each chunk; rseq forces to WHNF (fills C-array)
      chunks = map buildChunk bounds `using` parList rseq
  in VS.concat chunks

main :: IO ()
main = do
  args <- getArgs
  case args of
    [ls, bs, ws, cs] -> do
      let l = read ls; b = read bs; w = read ws
          numChunks = read cs
          n         = 2 ^ (l * b + w + 1) :: Int
          bytes     = (fromIntegral n * 16 :: Double) / (1024^(3::Int))
      putStrLn $ "State space N = 2^" ++ show (l*b+w+1)
              ++ " (" ++ show n ++ " states, ~"
              ++ printf "%.2f" bytes ++ " GB RAM)"
      let vec = VS.generate n $ \i -> if i == 0 then 1 :+ 0 else 0 :+ 0
      putStrLn $ "Parallel walk across " ++ show numChunks ++ " chunks..."
      timeIt $ do
        let !out = johnsonWalkParallel l b w vec numChunks
        putStrLn $ "First amplitude: " ++ show (VS.unsafeIndex out 0)
    _ -> putStrLn "Usage: ./johnsonWalkParallel <L> <b> <w> <num_chunks>\n\
                  \Example: ./johnsonWalkParallel 2 10 7 64 +RTS -N16 -s"
