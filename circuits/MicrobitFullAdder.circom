pragma circom 2.1.6;
// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// 1-bit boolean invariant enforcement + single-bit full addition
// b*(1-b) === 0 forces R1CS wires strictly binary {0,1}
// ============================================================

include "../node_modules/circomlib/circuits/comparators.circom";

template MicrobitFullAdder() {
    signal input a;
    signal input b;
    signal input cin;

    signal output sum;
    signal output cout;

    // Strict boolean invariant: b*(1-b) === 0
    a * (1 - a) === 0;
    b * (1 - b) === 0;
    cin * (1 - cin) === 0;

    signal axorb;
    axorb <== a + b - 2 * a * b;

    sum  <== axorb + cin - 2 * axorb * cin;
    cout <== a * b + cin * axorb;
}
