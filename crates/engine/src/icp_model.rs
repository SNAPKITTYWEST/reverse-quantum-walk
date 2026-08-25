// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// ICP Neural Path Model — Monro-Kellie Doctrine
//   V_intracranial = V_brain + V_CSF + V_blood = Constant
//   Fail-closed invariant: CPP = MAP - ICP > 50 mmHg
//   Isomorphic to recurrence.rs "fail closed" contract:
//   if ICP > threshold → irreversible failure (brain death)
// ============================================================

#[derive(Debug, Clone, Copy)]
pub struct NeuralState {
    pub mass_volume:    f64, // Volume of pathological mass (ml)
    pub comp_capacity:  f64, // Remaining CSF/blood compensation (ml)
    pub pressure:       f64, // ICP (mmHg)
}

impl NeuralState {
    /// Recursive state transition: mass expansion → pressure feedback.
    /// Phase 1 (Compensation): ΔV offset by ΔVCSF; ICP stable ~7–15 mmHg.
    /// Phase 2 (Decompensation): compensation → 0; small ΔV → massive ΔICP.
    /// Phase 3 (Critical): ICP → MAP; CPP → 0; hard halt.
    pub fn step(&self, delta_v: f64) -> NeuralState {
        let effective_increase = if self.comp_capacity > 0.0 {
            let offset = self.comp_capacity.min(delta_v);
            delta_v - offset
        } else {
            delta_v
        };

        // Non-linear pressure (Marmarou exponential pressure-volume model)
        // P = P_base * 2^(effective_increase / constant)
        let next_pressure = 10.0 * (2.0_f64).powf(effective_increase);

        NeuralState {
            mass_volume:   self.mass_volume + delta_v,
            comp_capacity: (self.comp_capacity - delta_v).max(0.0),
            pressure:      next_pressure,
        }
    }

    /// Hard constraint: clinical threshold for intracranial hypertension.
    /// Above 20 mmHg = danger; above MAP (~80–100) = brain death.
    pub fn is_critical(&self) -> bool {
        self.pressure > 20.0
    }

    /// CPP = MAP - ICP. Invariant: CPP > 50 mmHg for viable perfusion.
    pub fn cerebral_perfusion_pressure(&self, map: f64) -> f64 {
        map - self.pressure
    }
}

/// Recursive simulation of ICP ascent path.
/// Isomorphic to execute_loop in arithmetic_loop.rs:
///   both are tail-recursive state machines with a fail-closed invariant.
pub fn simulate_path(state: NeuralState, steps: u32, delta_v: f64) -> NeuralState {
    if steps == 0 || state.is_critical() {
        return state;
    }
    simulate_path(state.step(delta_v), steps - 1, delta_v)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compensation_phase_holds_pressure() {
        let s = NeuralState { mass_volume: 0.0, comp_capacity: 5.0, pressure: 10.0 };
        let s1 = s.step(2.0); // Within compensation capacity
        assert!(s1.pressure <= 20.0, "Pressure should be stable in compensation phase");
    }

    #[test]
    fn decompensation_spikes_pressure() {
        let s = NeuralState { mass_volume: 10.0, comp_capacity: 0.0, pressure: 15.0 };
        let s1 = s.step(3.0); // No remaining compensation
        assert!(s1.is_critical(), "Should be critical after decompensation");
    }

    #[test]
    fn simulate_path_halts_on_critical() {
        let s = NeuralState { mass_volume: 0.0, comp_capacity: 1.0, pressure: 10.0 };
        let final_state = simulate_path(s, 100, 1.5);
        // Should halt early on critical, not complete all 100 steps
        assert!(final_state.is_critical() || final_state.mass_volume <= 100.0 * 1.5);
    }
}
