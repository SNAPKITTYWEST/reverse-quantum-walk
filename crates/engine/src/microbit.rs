// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Companion: agda/PrimitiveShattering.agda
//            hardware/microbit_interlock.sv
//            circuits/MicrobitAdderAndDrift.circom
// Primitive Shattering Matrix: 256-bit F_p → 1-bit microbits
//   satisfying b*(1-b) = 0
// ============================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Microbit {
    pub val: bool,
}

impl Microbit {
    #[inline]
    pub fn new(val: bool) -> Self {
        Self { val }
    }

    /// Enforces structural constraint: b * (1 - b) == 0
    #[inline]
    pub fn assert_valid(&self) -> bool {
        let b = self.val as u8;
        (b * (1 - b)) == 0
    }

    #[inline]
    pub fn nand(a: Self, b: Self) -> Self {
        Self::new(!(a.val && b.val))
    }

    #[inline]
    pub fn xor(a: Self, b: Self) -> Self {
        Self::new(a.val ^ b.val)
    }

    #[inline]
    pub fn and(a: Self, b: Self) -> Self {
        Self::new(a.val && b.val)
    }

    #[inline]
    pub fn or(a: Self, b: Self) -> Self {
        Self::new(a.val || b.val)
    }
}

/// A 32-bit scalar shattered into 32 individual 1-bit microbit shards
#[derive(Debug, Clone)]
pub struct MicrobitShard32 {
    pub bits: [Microbit; 32],
}

impl MicrobitShard32 {
    pub fn shatter(val: u32) -> Self {
        let mut bits = [Microbit::new(false); 32];
        for i in 0..32 {
            bits[i] = Microbit::new(((val >> i) & 1) == 1);
        }
        Self { bits }
    }

    pub fn reconstruct(&self) -> u32 {
        let mut result = 0u32;
        for i in 0..32 {
            assert!(self.bits[i].assert_valid(), "Microbit integrity failure at bit {}", i);
            if self.bits[i].val {
                result |= 1 << i;
            }
        }
        result
    }

    /// Microbit Full-Adder Array: bounded-drift addition from single-bit logic.
    /// Returns (sum, drift_exceeded).
    pub fn add_bounded(&self, other: &Self, max_drift_bits: usize) -> (Self, Microbit) {
        let mut result_bits = [Microbit::new(false); 32];
        let mut carry = Microbit::new(false);

        for i in 0..32 {
            let a = self.bits[i];
            let b = other.bits[i];

            let axorb = Microbit::xor(a, b);
            let sum = Microbit::xor(axorb, carry);
            result_bits[i] = sum;

            let aandb = Microbit::and(a, b);
            let carry_and_axorb = Microbit::and(carry, axorb);
            carry = Microbit::or(aandb, carry_and_axorb);
        }

        let mut drift_exceeded = Microbit::new(false);
        for i in max_drift_bits..32 {
            drift_exceeded = Microbit::or(drift_exceeded, result_bits[i]);
        }
        drift_exceeded = Microbit::or(drift_exceeded, carry);

        (Self { bits: result_bits }, drift_exceeded)
    }
}
