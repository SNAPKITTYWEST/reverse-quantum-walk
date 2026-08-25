// ============================================================
// PROPRIETARY AND CONFIDENTIAL -- PRIOR ART SEALED
// Copyright (C) 2026 SNAPKITTYWEST / SnapKitty (Jessica).
// All Rights Reserved. Author: Ahmad Ali Parr
// License: SNAPKITTYWEST-PROPRIETARY-2026-001
// Companion: crates/engine/src/microbit.rs
//            agda/PrimitiveShattering.agda
// Bit-serial microbit interlock — fails closed on drift > MAX
// ============================================================

module microbit_interlock #(
    parameter int BIT_WIDTH          = 32,
    parameter int MAX_DRIFT_THRESHOLD = 1024
)(
    input  logic clk,
    input  logic rst_n,
    input  logic serial_bit_a,          // Shattered bit stream A (LSB first)
    input  logic serial_bit_b,          // Shattered bit stream B (LSB first)
    input  logic stream_valid,
    output logic [BIT_WIDTH-1:0] reconstructed_state,
    output logic interlock_tripped      // Fails closed if drift > MAX_DRIFT_THRESHOLD
);

    logic [BIT_WIDTH-1:0] shift_reg;
    logic [15:0]          drift_accumulator;
    logic                 carry;
    integer               bit_counter;

    wire sum_bit    = serial_bit_a ^ serial_bit_b ^ carry;
    wire next_carry = (serial_bit_a & serial_bit_b)
                    | (carry & (serial_bit_a ^ serial_bit_b));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg         <= '0;
            drift_accumulator <= '0;
            carry             <= 1'b0;
            bit_counter       <= 0;
            interlock_tripped <= 1'b0;
        end else if (stream_valid && !interlock_tripped) begin
            shift_reg <= {sum_bit, shift_reg[BIT_WIDTH-1:1]};
            carry     <= next_carry;

            if (serial_bit_a ^ serial_bit_b)
                drift_accumulator <= drift_accumulator + 1'b1;

            bit_counter <= bit_counter + 1;

            if (drift_accumulator > MAX_DRIFT_THRESHOLD)
                interlock_tripped <= 1'b1;

            if (bit_counter == BIT_WIDTH - 1) begin
                bit_counter <= 0;
                carry       <= 1'b0;
            end
        end
    end

    assign reconstructed_state = shift_reg;

endmodule
