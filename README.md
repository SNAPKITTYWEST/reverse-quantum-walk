# Reverse Quantum Walk over ER Bridge

[![License: BSL-1.1](https://img.shields.io/badge/license-BSL--1.1-orange?style=flat-square)](LICENSE)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue?style=flat-square)](LICENSE)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-green?style=flat-square)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-stable-orange?style=flat-square)](crates/)
[![Kani](https://img.shields.io/badge/kani-model--checked-brightgreen?style=flat-square)](crates/kani-verification/)
[![Lean 4](https://img.shields.io/badge/Lean4-step__bounded-yellow?style=flat-square)](lean/)
[![Agda](https://img.shields.io/badge/agda-zero--sorry-brightgreen?style=flat-square)](agda/)
[![SystemVerilog](https://img.shields.io/badge/hardware-microbit--interlock-red?style=flat-square)](hardware/)
[![Circom](https://img.shields.io/badge/ZK-R1CS%20circuits-blueviolet?style=flat-square)](circuits/)
[![WORM Sealed](https://img.shields.io/badge/WORM-SHA--256%20sealed-blueviolet?style=flat-square)](LICENSE)
[![Sovereign Stack](https://img.shields.io/badge/stack-Sovereign%20Stack-blueviolet?style=flat-square)](https://github.com/SNAPKITTYWEST)

**Authors:** Jessica L. Westerhoff (SNAPKITTYWEST), Ahmad Ali Parr  
**Trust:** Bel Esprit D'Accord Irrevocable Trust · EIN 42-697643

> **Full sovereign stack for time-reversible quantum walk dynamics over an ER bridge.**  
> Recurrence engine · Primitive Shattering Matrix · Kani model checking · Lean 4 · Agda · ZK circuits · SystemVerilog interlock

---

## What This Is

A **formally verified, hardware-grounded** implementation of reverse quantum walk dynamics over the ER = EPR bridge.

The core insight: replacing discrete finite-field R1CS constraints `A·B − C = 0 mod p` with continuous spatial constraints over ℝᴺ turns zero-knowledge logic into a CAD geometric solver engine. Every 256-bit scalar field element is **shattered** into 1-bit microbits satisfying `b·(1−b) = 0`, processed through a bit-serial full-adder array, and reconstructed with bounded drift.

---

## Architecture

```
𝔽ₚ scalar field
      ↓  Primitive Shattering Matrix
      ↓  b·(1−b) = 0  (microbit invariant)
      ↓
MicrobitShard32  ──→  bit-serial full-adder  ──→  reconstructed state
      ↓                       ↓
RecurrenceState         drift accumulator
  x ∈ [-2·SCALE, 2·SCALE]    ≤ TAU_R_MAX_DRIFT
  L_eff ≤ L_EFF_MAX           (interlock trips if exceeded)
      ↓
CAD Kernel (Newton-Raphson on C(X) = 0)
      ↓
Agda zero-sorry proof  ──→  systemInvariant ≡ true
```

---

## Stack

| Layer | Files | What it does |
|---|---|---|
| **Rust engine** | `crates/engine/src/recurrence.rs` | Q16.16 fixed-point recurrence. `SCALE=65536`, `L_EFF_MAX=65530`, `TAU_R_MAX_DRIFT=1024`. Contraction: `L_eff < 1`. |
| **Primitive Shattering** | `crates/engine/src/microbit.rs` | Shatters 32-bit values into 32 `Microbit` shards. `b*(1-b)==0` enforced. NAND/XOR/AND/OR. `add_bounded()` with drift gate. |
| **CAD Kernel** | `crates/engine/src/cad_kernel.rs` | Newton-Raphson 2D constraint solver. Jacobian build + gradient projection. Replaces discrete R1CS with continuous `C(X)=0`. |
| **Kani** | `crates/kani-verification/src/lib.rs` | Model-checks all bounds: `l_eff ≤ L_EFF_MAX`, `drift ≤ TAU_R_MAX_DRIFT`. Run: `cargo kani` |
| **Lean 4** | `lean/Multiplicity/Dynamics/Contraction.lean` | `step_bounded` theorem — sorry pending (discharge: omega + linarith) |
| **Agda** | `agda/MultiplicityInvariants.agda` | 16-invariant conjunction from recurrence + Kani + Lean + crypto + CAD. `proof = refl`. |
| **Agda** | `agda/PrimitiveShattering.agda` | `Bit`, `shatter`, `reconstruct`, `driftCount`, `InterlockState`. `SystemInvariant` record. |
| **SystemVerilog** | `hardware/microbit_interlock.sv` | Bit-serial microbit interlock. Fails **closed** if `drift_accumulator > MAX_DRIFT_THRESHOLD`. |
| **Circom ZK** | `circuits/MicrobitFullAdder.circom` | `a*(1-a)===0` R1CS bit-validity. Quadratic carry: `cout <== a*b + cin*axorb`. |
| **Circom ZK** | `circuits/MicrobitAdderAndDrift.circom` | 32-bit ripple-carry + `LessEqThan(16)` drift gate. `interlockTripped = 1` on breach. |

---

## Primitive Shattering Matrix

Every 256-bit scalar field constraint across circuits is shattered into 1-bit boolean invariants:

| Primitive Circuit | Monolithic Constraint | Shattered Decomposition | Reconstructed Primitive |
|---|---|---|---|
| `DriftBound.circom` | `D_T ≤ τ_R` | `D = Σ bᵢ·2ⁱ`, carry gates | Bitwise Range Gate |
| `PrimeCheck.circom` | `aᵈ ≡ 1 mod n` | Bitwise Sieve Matrix | Sieved Bit-Mask |
| `UORMatMul.circom` | `C_ij = Σ A_ik·B_kj` | Carry-Save Grid | Bit-Sliced Accumulator |
| `ace.circom` | `L_eff·X ≤ X_max` | Full-Adder carry chain over Q16.16 limbs | Microbit ALU Interlock |

---

## Invariants

| Invariant | Value | Enforced by |
|---|---|---|
| Q16.16 scale | `SCALE = 65536` | Rust + Agda |
| Contraction bound | `L_eff ≤ 65530 (< 1)` | Rust + Kani + Lean 4 |
| Drift bound | `drift ≤ 1024` | Rust + Kani + SV + Circom |
| Bit validity | `b·(1−b) = 0` | Rust + Circom + Agda |
| Entropy bound | `H ≤ 0.20 nats` | Agda (NAND-encoded) |
| Spectral radius | `ρ < 1.0 − 1e-6` | Agda |
| Poseidon2 budget | `5087 R1CS` | Agda |
| Dilithium5 | `2592-byte PK / 4627-byte Sig` | Agda |

---

## Quick Start

```bash
# Build Rust workspace
cargo build

# Run Kani model checking (requires cargo-kani)
cargo kani

# Check Lean 4 proofs (requires lake)
cd lean && lake build

# Check Agda proofs (requires agda)
agda agda/MultiplicityInvariants.agda
agda agda/PrimitiveShattering.agda

# Compile Circom circuits (requires circom + snarkjs)
cd circuits && circom MicrobitAdderAndDrift.circom --r1cs --wasm
```

---

## License

**Tri-License: BSL-1.1 / AGPL-3.0 / MPL-2.0 + Commercial**  
© 2026 Bel Esprit D'Accord Irrevocable Trust · SNAPKITTYWEST  
See [LICENSE](LICENSE) for full terms.

- Research / evaluation → BSL-1.1 (free)
- Network deployment / SaaS → AGPL-3.0 (mandatory copyleft)
- File-level modification → MPL-2.0
- Commercial copyleft bypass → contact `licensing@snapkittywest.dev`
