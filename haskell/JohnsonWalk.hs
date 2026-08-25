{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wall -Wno-orphans #-}
-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Extracted from: lean/WalkAA/WalkAmplitudeAmplification.lean
--   johnsonWalk = pure permutation reindexing (unitary by construction)
--   Corresponds to Lean theorem: johnsonWalk_unitary (zero sorry)
--
-- Build:  ghc -O2 JohnsonWalk.hs -o johnsonWalk
-- Run:    ./johnsonWalk <L> <b> <w> < state.txt
-- ============================================================

module Main where

import Data.Complex
import Data.Vector (Vector)
import qualified Data.Vector as V
import Numeric (showFFloat)
import System.Environment (getArgs)

--------------------------------------------------------------------
-- 1. Sizes
--------------------------------------------------------------------
msgSize :: Int -> Int -> Int
msgSize l b = 2 ^ (l * b)

cvSize :: Int -> Int
cvSize w = 2 ^ w

totalSize :: Int -> Int -> Int -> Int
totalSize l b w = msgSize l b * cvSize w * 2  -- ×2 for Flag

--------------------------------------------------------------------
-- 2. Cyclic shift on message index: m ↦ (m+1) mod msgSize
--    Corresponds to Lean: msgShift (Equiv.Perm on Msg L b)
--------------------------------------------------------------------
msgShift :: Int -> Int -> Int -> Int
msgShift l b m = (m + 1) `mod` msgSize l b

--------------------------------------------------------------------
-- 3. Lift to full state permutation
--    Corresponds to Lean: statePerm (Equiv.prodCongr msgShift Equiv.refl)
--------------------------------------------------------------------
statePerm :: Int -> Int -> Int -> Int -> Int
statePerm l b w idx =
  let cv'   = cvSize w
      msg'  = msgSize l b
      msg   = idx `div` (cv' * 2)
      rest  = idx `mod` (cv' * 2)
      newMsg = msgShift l b msg
  in newMsg * (cv' * 2) + rest

--------------------------------------------------------------------
-- 4. Walk operator: ψ(x) → ψ(statePerm x)  (pure reindexing)
--    Corresponds to Lean: johnsonWalk ψ = fun x => ψ (statePerm L b w x)
--    Unitary: permutation of basis preserves ‖ψ‖₂ exactly.
--------------------------------------------------------------------
johnsonWalk :: Int -> Int -> Int -> Vector (Complex Double) -> Vector (Complex Double)
johnsonWalk l b w psi =
  V.generate (totalSize l b w) $ \i ->
    V.unsafeIndex psi (statePerm l b w i)

--------------------------------------------------------------------
-- 5. I/O
--------------------------------------------------------------------
readState :: Int -> IO (Vector (Complex Double))
readState n = do
  nums <- map read . words <$> getContents
  let pairs = zip (evens nums) (odds nums)
      comps  = [ r :+ im | (r, im) <- pairs ]
  if length comps /= n
    then error $ "Expected " ++ show n ++ " complex numbers, got " ++ show (length comps)
    else return $ V.fromList comps
  where
    evens xs = [ xs !! i | i <- [0,2..length xs - 1] ]
    odds  xs = [ xs !! i | i <- [1,3..length xs - 1] ]

printState :: Vector (Complex Double) -> IO ()
printState vec = V.forM_ vec $ \c ->
  putStrLn $ fmt (realPart c) ++ " " ++ fmt (imagPart c)
  where fmt x = showFFloat (Just 6) x ""

main :: IO ()
main = do
  args <- getArgs
  case args of
    [ls, bs, ws] -> do
      let l = read ls; b = read bs; w = read ws
          n = totalSize l b w
      putStrLn $ "State size: " ++ show n ++ " amplitudes"
      psi    <- readState n
      let psi' = johnsonWalk l b w psi
      putStrLn "After Johnson walk (cyclic message shift):"
      printState psi'
    _ -> putStrLn "Usage: ./johnsonWalk <L> <b> <w>\n\
                  \Provide state vector on stdin as real imag pairs.\n\
                  \Example (L=1,b=2,w=1 => N=16):\n\
                  \  ./johnsonWalk 1 2 1 < state16.txt"
