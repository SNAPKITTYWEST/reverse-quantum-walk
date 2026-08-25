pragma circom 2.1.6;
// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Bit-serial microbit adder with accumulated drift interlock.
// LessEqThan(16): totalDrift <= maxDrift
// interlockTripped = 1 if drift exceeds maxDrift threshold
// ============================================================

pragma circom 2.1.6;

include "../node_modules/circomlib/circuits/comparators.circom";
include "./MicrobitFullAdder.circom";

template MicrobitAdderAndDrift(nBits, maxDrift) {
    signal input  a[nBits];
    signal input  b[nBits];

    signal output sum[nBits];
    signal output totalDrift;
    signal output interlockTripped;

    signal carries[nBits + 1];
    carries[0] <== 0;

    signal driftAccum[nBits + 1];
    driftAccum[0] <== 0;

    component adders[nBits];

    for (var i = 0; i < nBits; i++) {
        adders[i] = MicrobitFullAdder();
        adders[i].a   <== a[i];
        adders[i].b   <== b[i];
        adders[i].cin <== carries[i];

        sum[i]         <== adders[i].sum;
        carries[i + 1] <== adders[i].cout;

        signal bitDiff;
        bitDiff <== a[i] + b[i] - 2 * a[i] * b[i];
        driftAccum[i + 1] <== driftAccum[i] + bitDiff;
    }

    totalDrift <== driftAccum[nBits];

    component comp = LessEqThan(16);
    comp.in[0] <== totalDrift;
    comp.in[1] <== maxDrift;

    interlockTripped <== 1 - comp.out;
}

component main {public [maxDrift]} = MicrobitAdderAndDrift(32, 1024);
