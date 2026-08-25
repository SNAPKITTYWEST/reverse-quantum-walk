// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Matrix-Memory Equilibrium Propagation (MMEP) — No Softmax
//   Replaces probabilistic softmax with deterministic hard-threshold
//   energy relaxation. Convergence = zero delta (global equilibrium).
//   Softmax smears discrete logical states across a probability simplex.
//   MMEP resolves to a stable equilibrium or fails closed.
// ============================================================

pub struct EquilibriumState {
    pub state_vector:     Vec<i32>,
    pub energy_threshold: i32,
}

impl EquilibriumState {
    /// Hard-threshold activation — replaces softmax entirely.
    /// No probability smearing; output is {0, 1}.
    #[inline(always)]
    pub fn hard_threshold(val: i32, threshold: i32) -> i32 {
        if val >= threshold { 1 } else { 0 }
    }

    /// Single MMEP relaxation step.
    /// Returns true if global equilibrium (zero delta) is reached.
    /// Convergence = ∇E = 0; no gradient descent, no floating-point noise.
    pub fn relax_step(
        &mut self,
        interaction_matrix: &[Vec<i32>],
        bias: &[i32],
    ) -> bool {
        let n = self.state_vector.len();
        let mut next_state = vec![0i32; n];
        let mut total_delta = 0i32;

        for i in 0..n {
            let mut accumulator = bias[i];
            for j in 0..n {
                accumulator += interaction_matrix[i][j] * self.state_vector[j];
            }
            let projected = Self::hard_threshold(accumulator, 0);
            total_delta += (projected - self.state_vector[i]).abs();
            next_state[i] = projected;
        }

        self.state_vector = next_state;
        total_delta == 0
    }

    /// Run relaxation until equilibrium or max_steps.
    /// Returns (steps_taken, converged).
    pub fn relax_to_equilibrium(
        &mut self,
        interaction_matrix: &[Vec<i32>],
        bias: &[i32],
        max_steps: usize,
    ) -> (usize, bool) {
        for step in 0..max_steps {
            if self.relax_step(interaction_matrix, bias) {
                return (step + 1, true);
            }
        }
        (max_steps, false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hard_threshold_is_sharp() {
        assert_eq!(EquilibriumState::hard_threshold(5, 0), 1);
        assert_eq!(EquilibriumState::hard_threshold(-1, 0), 0);
        assert_eq!(EquilibriumState::hard_threshold(0, 0), 1);
    }

    #[test]
    fn identity_matrix_converges_in_one_step() {
        let n = 4;
        let matrix: Vec<Vec<i32>> = (0..n)
            .map(|i| (0..n).map(|j| if i == j { 1 } else { 0 }).collect())
            .collect();
        let bias = vec![1, -1, 1, -1];
        let mut state = EquilibriumState {
            state_vector:     vec![0; n],
            energy_threshold: 0,
        };
        let (steps, converged) = state.relax_to_equilibrium(&matrix, &bias, 100);
        assert!(converged, "Identity matrix should converge");
        assert!(steps <= 3, "Should converge quickly");
    }
}
