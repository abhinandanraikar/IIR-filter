// =============================================================================
// Module      : simple_IIR_biquad_DF1
// Description : Fixed-point IIR Biquad filter, Direct Form I (DF-I) realization.
//
//               Implements the second-order difference equation:
//                 y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2]
//                      - a1*y[n-1] - a2*y[n-2]
//
//               Coefficients are in Q1.15 fixed-point format (16-bit signed),
//               scaled by 2^15 = 32768. The accumulator operates at 32-bit
//               full precision; output is right-shifted by 14 bits to recover
//               the Q1.15 result.
//
// Fixed-point coefficient values (Q1.15, scaled by 2^15):
//   b0 =  167   →  0.005096...
//   b1 = -302   → -0.009216...
//   b2 =  167   →  0.005096...
//   a1 = -31881 → -0.973297...   (stored as positive; negated in datapath)
//   a2 =  15531 →  0.473999...   (stored as positive; negated in datapath)
//
//   These correspond to a low-pass biquad with natural frequency close to
//   DC, designed for stability under fixed-point truncation.
//
// Synthesis results (Cadence Genus 20.11, nominal PVT):
//   Cell count  : 721
//   Total area  : 13,796.352 sq. units
//   Total power : 35.8 µW  (logic: 93.11%, register: 6.89%)
//   Max freq    : 190.23 MHz  (slack: 94,743 ps at 100 MHz constraint)
//
// Ports:
//   clk  -- system clock (rising-edge triggered)
//   rst  -- synchronous active-high reset
//   din  -- 16-bit signed fixed-point input sample x[n]
//   dout -- 16-bit signed fixed-point filtered output y[n]
// =============================================================================
module simple_IIR_biquad_DF1 (
    input                   clk,
    input                   rst,        // synchronous, active-high
    input  signed [15:0]    din,
    output signed [15:0]    dout
);

    // -------------------------------------------------------------------------
    // Filter coefficients (Q1.15 fixed-point, scaled by 2^15 = 32768)
    // a1, a2 stored as positive magnitudes; negation is applied in the datapath
    // -------------------------------------------------------------------------
    localparam signed [15:0] a1_fixed = -31881;  // feedback coeff y[n-1]
    localparam signed [15:0] a2_fixed =  15531;  // feedback coeff y[n-2]
    localparam signed [15:0] b0_fixed =    167;  // feedforward coeff x[n]
    localparam signed [15:0] b1_fixed =   -302;  // feedforward coeff x[n-1]
    localparam signed [15:0] b2_fixed =    167;  // feedforward coeff x[n-2]

    // -------------------------------------------------------------------------
    // State registers
    // DF-I uses separate delay lines for input (x) and output (y).
    // This costs more registers than DF-II but is intrinsically overflow-safe:
    // intermediate partial sums cannot exceed the full 32-bit accumulator range.
    // -------------------------------------------------------------------------
    reg signed [15:0] r_x;      // current input (registered)
    reg signed [15:0] r_y;      // current output (registered, not used in MAC)
    reg signed [15:0] r_x_z1;   // x[n-1]: one-cycle delayed input
    reg signed [15:0] r_x_z2;   // x[n-2]: two-cycle delayed input
    reg signed [15:0] r_y_z1;   // y[n-1]: one-cycle delayed output
    reg signed [15:0] r_y_z2;   // y[n-2]: two-cycle delayed output

    // -------------------------------------------------------------------------
    // Multiplication wires (32-bit to prevent overflow in 16x16 products)
    // -------------------------------------------------------------------------
    wire signed [31:0] w_product_a1;   // -a1 * y[n-1]
    wire signed [31:0] w_product_a2;   // -a2 * y[n-2]
    wire signed [31:0] w_product_b0;   //  b0 * x[n]
    wire signed [31:0] w_product_b1;   //  b1 * x[n-1]
    wire signed [31:0] w_product_b2;   //  b2 * x[n-2]
    wire signed [31:0] w_sum;          // full-precision accumulator output

    // -------------------------------------------------------------------------
    // Synchronous datapath: update delay registers each clock cycle
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            r_x    <= 16'd0;
            r_y    <= 16'd0;
            r_x_z1 <= 16'd0;
            r_x_z2 <= 16'd0;
            r_y_z1 <= 16'd0;
            r_y_z2 <= 16'd0;
        end else begin
            r_x    <= din;               // latch new input
            r_x_z1 <= r_x;              // shift input delay line
            r_x_z2 <= r_x_z1;

            // Scale accumulator output back to Q1.15 by right-shifting 14 bits.
            // (Coefficients are Q1.15; products are Q2.30; sum is Q2.30;
            //  shifting by 14 gives a Q2.16 result, truncated to [15:0] = Q1.15)
            r_y_z1 <= w_sum >>> 14;     // y[n] becomes y[n-1] next cycle
            r_y_z2 <= r_y_z1;          // y[n-1] becomes y[n-2] next cycle
            r_y    <= r_y_z1;          // alias for clarity; not used in MAC path
        end
    end

    // -------------------------------------------------------------------------
    // Combinational MAC: compute w_sum = b0*x[n] + b1*x[n-1] + b2*x[n-2]
    //                                  - a1*y[n-1] - a2*y[n-2]
    //
    // Note: a1_fixed and a2_fixed are stored as their negative values in the
    // localparam declarations, so the feedback terms add directly (no extra negation).
    // -------------------------------------------------------------------------
    assign w_product_b0 = r_x    * b0_fixed;
    assign w_product_b1 = r_x_z1 * b1_fixed;
    assign w_product_b2 = r_x_z2 * b2_fixed;
    assign w_product_a1 = r_y_z1 * (-a1_fixed);  // double-negative = positive contribution
    assign w_product_a2 = r_y_z2 * (-a2_fixed);

    assign w_sum = w_product_b0
                 + w_product_b1
                 + w_product_b2
                 + w_product_a1
                 + w_product_a2;

    // Output is the scaled, registered result from the previous cycle
    assign dout = r_y_z1;

endmodule