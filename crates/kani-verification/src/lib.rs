// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Kani model-checking harness for recurrence engine bounds.
// Run: cargo kani
// ============================================================

use engine::recurrence::{RecurrenceState, StepParameters, SCALE, L_EFF_MAX, TAU_R_MAX_DRIFT};

#[cfg(kani)]
#[kani::proof]
#[kani::unroll(4)]
pub fn verify_hardened_perturbation_stability() {
    let state: RecurrenceState = kani::any();
    let params: StepParameters = kani::any();
    let noise: i32 = kani::any();

    kani::assume(state.x >= -SCALE * 2 && state.x <= SCALE * 2);
    kani::assume(state.drift >= 0 && state.drift <= TAU_R_MAX_DRIFT / 2);

    kani::assume(params.xi >= 0 && params.xi <= SCALE / 2);
    kani::assume(params.lambda >= 0 && params.lambda <= SCALE / 4);
    kani::assume(params.gain >= -64 && params.gain <= 64);
    kani::assume(noise >= -32 && noise <= 32);

    let next_state = state.step(&params, noise);
    let l_eff = next_state.compute_l_eff(&state);

    kani::assert(l_eff <= L_EFF_MAX);
    kani::assert(next_state.drift <= TAU_R_MAX_DRIFT);
}
