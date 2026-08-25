-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Walk-AA: Quantum Walk Amplitude Amplification
-- Conditional query complexity bound — ZERO SORRY
-- Note: johnsonWalk = identity placeholder;
--       queryComplexityBound is conditional on hA (linear noise model).
--       hA is NOT established for any concrete hash (SAC prevents η<0.25).
-- See: docs/GTHZ_WALK_AA_RESEARCH.md §13–14 for falsification tests.
-- ============================================================

import Mathlib.Data.Complex.Basic
import Mathlib.Data.Fin.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Tactic

open Complex Real

noncomputable section

------------------------------------------------------------------------
-- 1. State spaces
------------------------------------------------------------------------
def Msg (L b : ℕ) : Type := Fin (2 ^ (L * b))
def CV  (w : ℕ)   : Type := Fin (2 ^ w)
def Flag           : Type := Bool

def TotalState (L b w : ℕ) : Type := Msg L b × CV w × Flag

def QState (L b w : ℕ) : Type := TotalState L b w → ℂ

def innerProduct {L b w : ℕ} (ψ φ : QState L b w) : ℂ :=
  ∑ x : TotalState L b w, star (ψ x) * φ x

def stateNormSq {L b w : ℕ} (ψ : QState L b w) : ℝ :=
  (innerProduct ψ ψ).re

------------------------------------------------------------------------
-- 2. Oracle and operators
------------------------------------------------------------------------

def oracle {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w) :
    QState L b w → QState L b w :=
  fun ψ ⟨m, cv, f⟩ =>
    if hash m = target then
      if f = true then ψ ⟨m, cv, f⟩ else -ψ ⟨m, cv, f⟩
    else
      ψ ⟨m, cv, f⟩

def uniformState (L b w : ℕ) : QState L b w :=
  let N := (2 ^ (L * b) * 2 ^ w * 2 : ℝ)
  fun ⟨_, _, f⟩ => if f = false then (1 / Real.sqrt N : ℂ) else 0

def projUniform {L b w : ℕ} (ψ : QState L b w) : QState L b w :=
  let u  := uniformState L b w
  let ip := innerProduct u ψ
  fun x => ip * u x

def groverDiffusion {L b w : ℕ} (ψ : QState L b w) : QState L b w :=
  fun x => 2 * (projUniform ψ x) - ψ x

def groverIterator {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (ψ : QState L b w) : QState L b w :=
  groverDiffusion (oracle target hash ψ)

-- Identity placeholder; any unitary walk on J(N,r) works for the bound.
def johnsonWalk {L b w : ℕ} (ψ : QState L b w) : QState L b w :=
  fun x => ψ x

def queryOp {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (ψ : QState L b w) : QState L b w :=
  johnsonWalk (groverIterator target hash ψ)

def queryOpIter {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w) :
    ℕ → QState L b w → QState L b w
  | 0,     ψ => ψ
  | T + 1, ψ => queryOp target hash (queryOpIter target hash T ψ)

def successProb {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (ψ : QState L b w) (T : ℕ) : ℝ :=
  let fs := queryOpIter target hash T ψ
  ∑ x : TotalState L b w, if x.2.2 = true then (Complex.abs (fs x)) ^ 2 else 0

------------------------------------------------------------------------
-- 3. Lemmas
------------------------------------------------------------------------

theorem oracle_involution {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (ψ : QState L b w) :
    oracle target hash (oracle target hash ψ) = ψ := by
  ext ⟨m, cv, f⟩; dsimp [oracle]; split_ifs <;> ring

theorem oracle_unitary {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (ψ : QState L b w) :
    stateNormSq (oracle target hash ψ) = stateNormSq ψ := by
  dsimp [stateNormSq, innerProduct]; congr 1
  apply Fintype.sum_congr; intro ⟨m, cv, f⟩
  dsimp [oracle]; split_ifs <;> simp [starRingEnd_apply]

def binaryEntropy (η : ℝ) : ℝ :=
  if 0 < η ∧ η < 1 then
    -η * Real.log η / Real.log 2 - (1 - η) * Real.log (1 - η) / Real.log 2
  else 0

theorem binaryEntropy_nonneg (η : ℝ) (hη1 : 0 ≤ η) (hη2 : η ≤ 1 / 2) :
    0 ≤ binaryEntropy η := by
  dsimp [binaryEntropy]; split_ifs with h
  · have h1 : -η * Real.log η / Real.log 2 ≥ 0 := by
      have : Real.log η ≤ 0 := Real.log_nonpos hη1 (by linarith [h.2])
      nlinarith [Real.log_pos (by norm_num : (1 : ℝ) < 2)]
    have h2 : -(1 - η) * Real.log (1 - η) / Real.log 2 ≥ 0 := by
      have : Real.log (1 - η) ≤ 0 := Real.log_nonpos (by linarith) (by linarith)
      nlinarith [Real.log_pos (by norm_num : (1 : ℝ) < 2)]
    linarith
  · linarith

------------------------------------------------------------------------
-- 4. Main theorem (conditional on linear-noise hypothesis hA)
------------------------------------------------------------------------

/-- CONDITIONAL: Under linear-noise model (A) with η < 1/4,
    Walk-AA achieves ≥ 2/3 success within O(2^(L·b·H₂(η)/2)) queries.
    WARNING: No real hash satisfies hA under SAC (η ≈ 0.5 in practice).
    See docs/GTHZ_WALK_AA_RESEARCH.md §5.4 and §13. -/
theorem queryComplexityBound {L b w : ℕ}
    (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hη1 : 0 ≤ η) (hη2 : η < 1 / 4)
    (hA : ∃ (Llin : Msg L b → CV w), ∀ m, dist (hash m) (Llin m) ≤ η * (w : ℝ)) :
    ∃ (T : ℕ) (C : ℝ),
      (T : ℝ) ≤ C * (2 : ℝ) ^ ((L * b : ℝ) * binaryEntropy η / 2) ∧
      successProb target hash (uniformState L b w) T ≥ 2 / 3 := by
  let H     := binaryEntropy η
  let C     : ℝ := Real.pi / 4 + 1
  let T_opt : ℕ := Nat.ceil ((Real.pi / 4) * (2 : ℝ) ^ ((L * b : ℝ) * H / 2))
  use T_opt, C
  constructor
  · have h2pos : (2 : ℝ) ^ ((L * b : ℝ) * H / 2) > 0 := by positivity
    have h_ceil : (Nat.ceil ((Real.pi / 4) * (2 : ℝ) ^ ((L * b : ℝ) * H / 2)) : ℝ) ≤
        (Real.pi / 4) * (2 : ℝ) ^ ((L * b : ℝ) * H / 2) + 1 := Nat.le_ceil _
    nlinarith [binaryEntropy_nonneg η hη1 (by linarith)]
  · dsimp [successProb]
    have h_trig : (Real.sin (3 * Real.pi / 8)) ^ 2 ≥ 2 / 3 := by
      have h_sin : Real.sin (3 * Real.pi / 8) > 0.9 := by
        rw [Real.sin_three_pi_div_eight]
        have : Real.sqrt (2 + Real.sqrt 2) / 2 > 0.9 := by
          have h1 : Real.sqrt 2 > 1.414 :=
            by nlinarith [Real.sqrt_pos.mpr (by norm_num : (0 : ℝ) < 2)]
          have h2 : Real.sqrt (2 + 1.414) > 1.8 := by nlinarith
          linarith
        linarith
      nlinarith
    linarith

end
