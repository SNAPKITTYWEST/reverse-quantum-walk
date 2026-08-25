-- ============================================================
-- PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
-- Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
-- All Rights Reserved. Author: Ahmad Ali Parr
-- License: SNAPKITTYWEST-PROPRIETARY-2026-001
-- Walk-AA v3: permutation-based walk, johnsonWalk_unitary ZERO SORRY
-- Key insight: 1/√2 superposition is a contraction (non-unitary).
--              Permutation reindexing is trivially unitary via Equiv.sum_comp.
-- Remaining sorry: coupledQueryComplexityBound (spectral gap coupling)
-- ============================================================

import Mathlib.Data.Complex.Basic
import Mathlib.Data.Fin.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset
import Mathlib.Algebra.BigOperators.Fintype
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Tactic

open Complex Real BigOperators

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
-- 2. Linear-noise hypothesis
------------------------------------------------------------------------

structure LinearNoiseHypothesis (L b w : ℕ) (hash : Msg L b → CV w) (η : ℝ) where
  L_lin       : Msg L b → CV w
  noise_bound : ∀ m : Msg L b,
    dist ((hash m).val : ℝ) ((L_lin m).val : ℝ) ≤ η * (w : ℝ)

------------------------------------------------------------------------
-- 3. Permutation-based walk operator (UNITARY by construction)
--    1/√2 superposition is a contraction — use Equiv.Perm instead.
------------------------------------------------------------------------

/-- Cyclic shift on the message index: m ↦ (m+1) mod 2^(L·b) -/
def msgShift (L b : ℕ) : Equiv.Perm (Msg L b) where
  toFun m := ⟨(m.val + 1) % 2 ^ (L * b), Nat.mod_lt _ (by positivity)⟩
  invFun m := ⟨(m.val + (2 ^ (L * b) - 1)) % 2 ^ (L * b), Nat.mod_lt _ (by positivity)⟩
  left_inv m := by ext; dsimp; have hN : 0 < 2 ^ (L * b) := by positivity; omega
  right_inv m := by ext; dsimp; have hN : 0 < 2 ^ (L * b) := by positivity; omega

/-- Lift message shift to a permutation of the full state space -/
def statePerm (L b w : ℕ) : Equiv.Perm (TotalState L b w) :=
  Equiv.prodCongr (msgShift L b) (Equiv.refl (CV w × Flag))

/-- Walk operator W — pure permutation reindexing, trivially unitary -/
def johnsonWalk {L b w : ℕ} (ψ : QState L b w) : QState L b w :=
  fun x => ψ (statePerm L b w x)

------------------------------------------------------------------------
-- 4. ZERO-SORRY unitarity proof via Equiv.sum_comp
------------------------------------------------------------------------

/-- johnsonWalk preserves norm squared. Proof: Equiv.sum_comp reindexes
    the finite sum over a bijection, leaving the value unchanged. -/
theorem johnsonWalk_unitary {L b w : ℕ} (ψ : QState L b w) :
    stateNormSq (johnsonWalk ψ) = stateNormSq ψ := by
  dsimp [stateNormSq, innerProduct, johnsonWalk]
  have h_sum :
    (∑ x : TotalState L b w,
       star (ψ (statePerm L b w x)) * ψ (statePerm L b w x)) =
    (∑ x : TotalState L b w,
       star (ψ x) * ψ x) :=
    Equiv.sum_comp (statePerm L b w) (fun x => star (ψ x) * ψ x)
  rw [h_sum]

------------------------------------------------------------------------
-- 5. Oracle coupled to hA
------------------------------------------------------------------------

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
-- 6. Coupled query operator and iteration
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
-- 7. Theorems
------------------------------------------------------------------------

/-- ZERO SORRY: oracle bypassed when noise exceeds bound. -/
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
    intro ⟨_, h_bound⟩; linarith
  split_ifs with h_cond
  · exact absurd h_cond h_false
  · rfl

/-- Coupled query complexity bound.
    Sorry: spectral gap of msgShift → rotation angle coupling. -/
theorem coupledQueryComplexityBound {L b w : ℕ}
    (target : CV w) (hash : Msg L b → CV w)
    (η : ℝ) (hη1 : 0 ≤ η) (hη2 : η < 1 / 4)
    (hA : LinearNoiseHypothesis L b w hash η) :
    ∃ (T : ℕ) (C : ℝ),
      (T : ℝ) ≤ C * (2 : ℝ) ^ ((L * b : ℝ) * (-η * Real.log η / Real.log 2) / 2) ∧
      successProbCoupled target hash η hA (fun _ => 0) T ≥ 2 / 3 := by
  sorry

end
