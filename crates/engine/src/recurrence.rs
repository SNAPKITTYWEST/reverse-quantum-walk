// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Companion: lean/Multiplicity/Dynamics/Contraction.lean
//            crates/kani-verification/src/lib.rs
// ============================================================

pub const SCALE: i32 = 65536;           // Q16.16 fixed-point unit
pub const L_EFF_MAX: i32 = 65530;       // strict contraction < 1
pub const TAU_R_MAX_DRIFT: i32 = 1024;  // max accumulated drift

#[derive(Clone, Copy)]
pub struct RecurrenceState {
    pub x: i32,
    pub drift: i32,
}

#[derive(Clone, Copy)]
pub struct StepParameters {
    pub xi: i32,
    pub lambda: i32,
    pub gain: i32,
}

impl RecurrenceState {
    pub fn step(&self, params: &StepParameters, noise: i32) -> RecurrenceState {
        let xi_x = ((self.x as i64 * params.xi as i64) / SCALE as i64) as i32;
        let tx = self.x.clamp(-SCALE, SCALE) / 2;
        let lam_tx = ((params.lambda as i64 * tx as i64) / SCALE as i64) as i32;

        let next_x = xi_x.saturating_add(lam_tx).saturating_add(params.gain);
        let next_drift = self.drift.saturating_add(noise.abs());

        RecurrenceState { x: next_x, drift: next_drift }
    }

    pub fn compute_l_eff(&self, prev: &RecurrenceState) -> i32 {
        if prev.x == 0 {
            return 0;
        }
        ((self.x.abs() as i64 * SCALE as i64) / prev.x.abs() as i64) as i32
    }
}
