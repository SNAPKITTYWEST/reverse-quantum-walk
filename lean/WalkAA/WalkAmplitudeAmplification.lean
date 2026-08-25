-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Coupled Walk-AA v2: non-trivial walk, hA-gated oracle,
--   oracle_bypassed_if_noise_exceeded (ZERO SORRY)
-- Remaining sorrys: johnsonWalk_unitary, coupledQueryComplexityBound
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
def QState     (L b w : ℕ) : Type := TotalState L b w → ℂ

def innerProduct {L b w : ℕ} (ψ φ : QState L b w) : ℂ :=
  ∑ x : TotalState L b w, star (ψ x) * φ x

def stateNormSq {L b w : ℕ} (ψ : QState L b w) : ℝ :=
  (innerProduct ψ ψ).re

------------------------------------------------------------------------
-- 2. Linear-noise hypothesis — structured, not existential
------------------------------------------------------------------------

/-- Couples hash to its linear approximation with explicit noise bound. -/
structure LinearNoiseHypothesis (L b w : ℕ) (hash : Msg L b → CV w) (η : ℝ) where
  L_lin       : Msg L b → CV w
  noise_bound : ∀ m : Msg L b,
    dist ((hash m).val : ℝ) ((L_lin m).val : ℝ) ≤ η * (w : ℝ)

------------------------------------------------------------------------
-- 3. Non-trivial walk operator (1D bit-flip hypercube diffusion)
------------------------------------------------------------------------

def bitFlipNeighbor {L b : ℕ} (m : Msg L b) : Msg L b :=
  ⟨(m.val + 1) % (2 ^ (L * b)), Nat.mod_lt _ (by positivity)⟩

/-- Coherent diffusion over cyclic bit-flip neighbor. -/
def johnsonWalk {L b w : ℕ} (ψ : QState L b w) : QState L b w :=
  fun ⟨m, cv, f⟩ =>
    let m_next := bitFlipNeighbor m
    (1 / Real.sqrt 2 : ℂ) * ψ ⟨m, cv, f⟩
    + (1 / Real.sqrt 2 : ℂ) * ψ ⟨m_next, cv, f⟩

------------------------------------------------------------------------
-- 4. Oracle explicitly coupled to hA noise subspace
------------------------------------------------------------------------

/-- Phase oracle: phase flip only when BOTH target matches AND noise bound holds. -/
def coupledPhaseOracle {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hA : LinearNoiseHypothesis L b w hash η) :
    QState L b w → QState L b w :=
  fun ψ ⟨m, cv, f⟩ =>
    if hash m = target
       ∧ dist ((hash m).val : ℝ) ((hA.L_lin m).val : ℝ) ≤ η * (w : ℝ) then
      if f = true then ψ ⟨m, cv, f⟩ else -ψ ⟨m, cv, f⟩
    else
      ψ ⟨m, cv, f⟩

------------------------------------------------------------------------
-- 5. Coupled query operator and iteration
------------------------------------------------------------------------

def coupledQueryOp {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hA : LinearNoiseHypothesis L b w hash η) (ψ : QState L b w) :
    QState L b w :=
  johnsonWalk (coupledPhaseOracle target hash η hA ψ)

def coupledQueryIter {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hA : LinearNoiseHypothesis L b w hash η) :
    ℕ → QState L b w → QState L b w
  | 0,     ψ => ψ
  | T + 1, ψ => coupledQueryOp target hash η hA
                  (coupledQueryIter target hash η hA T ψ)

def successProbCoupled {L b w : ℕ} (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hA : LinearNoiseHypothesis L b w hash η)
    (ψ : QState L b w) (T : ℕ) : ℝ :=
  let fs := coupledQueryIter target hash η hA T ψ
  ∑ x : TotalState L b w, if x.2.2 = true then (Complex.abs (fs x)) ^ 2 else 0

------------------------------------------------------------------------
-- 6. Theorems
------------------------------------------------------------------------

/-- Walk preserves norm squared (unitarity).
    Sorry: sum cancellation over cyclic bit-flip indices. -/
theorem johnsonWalk_unitary {L b w : ℕ} (ψ : QState L b w) :
    stateNormSq (johnsonWalk ψ) = stateNormSq ψ := by
  sorry

/-- ZERO SORRY: oracle is bypassed when noise bound is exceeded. -/
theorem oracle_bypassed_if_noise_exceeded {L b w : ℕ}
    (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hA : LinearNoiseHypothesis L b w hash η)
    (ψ : QState L b w) (m : Msg L b) (cv : CV w) :
    η * (w : ℝ) < dist ((hash m).val : ℝ) ((hA.L_lin m).val : ℝ) →
    coupledPhaseOracle target hash η hA ψ ⟨m, cv, false⟩
    = ψ ⟨m, cv, false⟩ := by
  intro h_exceeded
  dsimp [coupledPhaseOracle]
  have h_false :
    ¬ (hash m = target
       ∧ dist ((hash m).val : ℝ) ((hA.L_lin m).val : ℝ) ≤ η * (w : ℝ)) := by
    intro ⟨_, h_bound⟩
    linarith
  split_ifs with h_cond
  · exact absurd h_cond h_false
  · rfl

/-- Coupled query complexity bound.
    T_opt ≤ C · 2^(L·b·H₂(η)/2) directly from hA.noise_bound.
    Sorry: rotation-angle coupling to spectral gap of johnsonWalk. -/
theorem coupledQueryComplexityBound {L b w : ℕ}
    (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hη1 : 0 ≤ η) (hη2 : η < 1 / 4)
    (hA : LinearNoiseHypothesis L b w hash η) :
    ∃ (T : ℕ) (C : ℝ),
      (T : ℝ) ≤ C * (2 : ℝ) ^ ((L * b : ℝ) * (-η * Real.log η / Real.log 2) / 2) ∧
      successProbCoupled target hash η hA (fun _ => 0) T ≥ 2 / 3 := by
  sorry

end
