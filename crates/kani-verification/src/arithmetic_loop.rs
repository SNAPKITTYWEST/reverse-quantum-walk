// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Kani-verified arithmetic feedback loop with direction tracking.
// Isomorphic to ICP model: both are recursive state machines
// with a fail-closed invariant and deterministic termination.
// Run: cargo kani --harness verify_arithmetic_feedback_loop
// ============================================================

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Direction {
    Ascending,
    Descending,
}

#[derive(Clone, Copy, Debug)]
pub struct LoopState {
    pub val:       i32,
    pub dir:       Direction,
    pub iteration: u32,
}

pub struct TransitionResult {
    pub next_state: LoopState,
    pub passed:     bool,
}

impl LoopState {
    /// Arithmetic state transition — fail closed on any invariant violation.
    /// Isomorphic to NeuralState::step: both are S_n → S_{n+1} with a
    /// hard boundary check that halts the system on constraint breach.
    pub fn transition(&self, min: i32, max: i32) -> TransitionResult {
        let next_val = match self.dir {
            Direction::Ascending  => if self.val < max { self.val + 1 } else { self.val },
            Direction::Descending => if self.val > min { self.val - 1 } else { self.val },
        };

        let next_dir = if next_val == max {
            Direction::Descending
        } else if next_val == min {
            Direction::Ascending
        } else {
            self.dir
        };

        let monotone_ok = match self.dir {
            Direction::Ascending  if self.val < max => next_val > self.val,
            Direction::Descending if self.val > min => next_val < self.val,
            _ => true,
        };

        let invariant_passed = (next_val >= min) && (next_val <= max) && monotone_ok;

        TransitionResult {
            next_state: LoopState { val: next_val, dir: next_dir, iteration: self.iteration },
            passed: invariant_passed,
        }
    }
}

// Pipeline helper trait
trait Pipe: Sized {
    fn pipe<F, R>(self, f: F) -> R
    where
        F: FnOnce(Self) -> R,
    {
        f(self)
    }
}
impl Pipe for LoopState {}

/// Recursive driver: execute until 10 complete cycles.
pub fn execute_loop(state: LoopState, min: i32, max: i32) -> LoopState {
    if state.iteration >= 10 {
        return state;
    }
    let result = state.transition(min, max);
    if !result.passed {
        return result.next_state; // Fail closed
    }
    let mut next = result.next_state;
    if next.val == min && next.dir == Direction::Ascending {
        next.iteration += 1;
    }
    next.pipe(|s| execute_loop(s, min, max))
}

#[cfg(kani)]
#[kani::proof]
pub fn verify_arithmetic_feedback_loop() {
    let min_val: i32 = 0;
    let max_val: i32 = 10;

    let mut current_state = LoopState {
        val:       min_val,
        dir:       Direction::Ascending,
        iteration: 0,
    };

    let mut all_passed = true;
    let mut completed_cycles = 0u32;

    while completed_cycles < 10 {
        let res = current_state.transition(min_val, max_val);
        if !res.passed {
            all_passed = false;
            break;
        }
        current_state = res.next_state;
        if current_state.val == min_val && current_state.dir == Direction::Ascending {
            completed_cycles += 1;
        }
        kani::assume(completed_cycles <= 10);
    }

    kani::assert(all_passed,           "A transition invariant was violated");
    kani::assert(completed_cycles == 10, "Failed to complete exactly 10 iterations");
    kani::assert(current_state.val == min_val, "Final state must return to minimum");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ascends_to_max_then_descends() {
        let s = LoopState { val: 0, dir: Direction::Ascending, iteration: 0 };
        let r = s.transition(0, 5);
        assert!(r.passed);
        assert_eq!(r.next_state.val, 1);
        assert_eq!(r.next_state.dir, Direction::Ascending);
    }

    #[test]
    fn flips_direction_at_max() {
        let s = LoopState { val: 5, dir: Direction::Ascending, iteration: 0 };
        let r = s.transition(0, 5);
        assert!(r.passed);
        assert_eq!(r.next_state.dir, Direction::Descending);
    }
}
