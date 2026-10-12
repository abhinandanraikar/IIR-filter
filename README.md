# IIR Biquad Filter — Direct Form I Physical Design

A fixed-point IIR (Infinite Impulse Response) Biquad filter implemented in Verilog, synthesized using Cadence Genus, and verified against a MATLAB floating-point reference. Achieved a **13,796 sq. unit** footprint at **35.8 µW** total power with a maximum operating frequency of **190.23 MHz**.

*DSD Final Project — PES University, Nov 2025. Team: Abhinandan Raikar, Arpan Murthy, Kshitij Nagashetti, Manasa Ajit.*

---

## Table of contents

- [Overview](#overview)
- [Repository structure](#repository-structure)
- [Filter design](#filter-design)
  - [Architecture: Direct Form I](#architecture-direct-form-i)
  - [Fixed-point representation](#fixed-point-representation)
  - [Coefficients](#coefficients)
- [Synthesis results](#synthesis-results)
- [Simulation and verification](#simulation-and-verification)
- [How to run](#how-to-run)
- [Tools](#tools)

---

## Overview

This project implements a second-order IIR Biquad filter in the Direct Form I (DF-I) topology, targeting high numerical stability under fixed-point arithmetic constraints. The design was synthesized through a full logic synthesis flow in Cadence Genus using a standard cell library under nominal operating conditions.

The filter was verified by comparing Verilog simulation output against a MATLAB floating-point reference implementation using the same coefficient values. The RMSE of **5.174657** confirms that the quantisation error introduced by Q1.15 fixed-point representation is within acceptable bounds.

---

## Repository structure

```
iir-biquad-df1/
├── rtl/
│   └── simple_IIR_biquad_DF1.v       # Filter RTL (synthesizable Verilog)
├── tb/
│   └── simple_IIR_biquad_DF1_tb.v    # Testbench with file I/O stimulus
├── sim/
│   └── run_sim.tcl                    # Vivado xsim simulation script
├── matlab/
│   └── verify_iir_output.m           # MATLAB reference model + RMSE comparison
└── docs/
    ├── area.rpt               # Cadence Genus area report
    ├── power.rpt               # Cadence Genus power report
    ├── timing.rpt            # Cadence Genus timing report
    └── output_plots.png               # Simulation waveform overlay (Verilog vs MATLAB)
```

---

## Filter design

### Architecture: Direct Form I

The DF-I biquad directly maps the second-order difference equation to hardware:

```
y[n] = b0·x[n] + b1·x[n-1] + b2·x[n-2] - a1·y[n-1] - a2·y[n-2]
```

This uses separate delay lines for the input (feedforward path) and output (feedback path), resulting in 4 delay registers total (x[n-1], x[n-2], y[n-1], y[n-2]).

**Why DF-I over DF-II?** DF-II uses fewer delay elements but is more susceptible to internal node overflow in fixed-point implementations. DF-I separates the feedforward and feedback computations, meaning intermediate overflow in the input delay line cannot propagate into the feedback path. For fixed-point DSP designs where coefficient quantisation errors can shift poles toward the unit circle, this structural separation is critical for maintaining stability.

### Fixed-point representation

All signals and coefficients use **Q1.15** format: 1 sign bit, 0 integer bits, 15 fractional bits. The scale factor is 2^15 = 32768.

The 16×16 multipliers produce 32-bit products, which accumulate at full Q2.30 precision. The output is recovered by arithmetic right-shifting the 32-bit accumulator by 14 bits, yielding a Q2.16 result truncated to 16 bits.

### Coefficients

| Parameter | Raw value (Q1.15) | Floating-point equivalent |
|---|---|---|
| b0 | 167 | 0.005096 |
| b1 | -302 | -0.009216 |
| b2 | 167 | 0.005096 |
| a1 | -31881 | -0.973297 |
| a2 | 15531 | 0.473999 |

The feedback coefficients a1 and a2 are stored as their negative magnitudes in the `localparam` declarations. The datapath applies a second negation (`-a1_fixed`, `-a2_fixed`), resulting in the correct positive feedback contribution to the accumulator.

---

## Synthesis results

Synthesized in **Cadence Genus 20.11** under nominal operating conditions (balanced tree, enclosed wireload, timing library area mode):

| Metric | Value |
|---|---|
| Cell count | 721 |
| Total area | 13,796.352 sq. units |
| Total power | 35.8 µW |
| — Logic (93.11%) | 4.851 × 10⁻⁴ W |
| — Register (6.89%) | 3.588 × 10⁻⁵ W |
| Max operating frequency | **190.23 MHz** |
| Critical path slack | 94,743 ps (at 100 MHz constraint) |
| Critical path | rst → g137 (INV) → g145 (AND2X1) → r_y_z1_reg[1]/D |

The design is heavily logic-dominated (93.11%), consistent with a MAC-heavy fixed-point filter where the 5 multiplier trees and accumulator adder tree dominate switching activity. Zero clock or memory power is expected since the design uses no dedicated clock buffers or memories in isolation.

The large positive slack (94,743 ps at a 100 MHz constraint) indicates significant timing margin — the design could be re-synthesized with a tighter clock constraint to trade area and power for higher throughput if needed.

---

## Simulation and verification

The testbench reads a 1000-sample stimulus from `simple_IIR_biquad_test_stimulus.txt`, applies a synchronous reset, then drives samples at 10 MHz. Both the input and output are logged to text files for MATLAB comparison.

MATLAB cross-verification using `verify_iir_output.m` applies the same coefficients in floating-point and computes the RMSE between the two output sequences:

**RMSE = 5.174657**

This quantisation error is attributable entirely to the Q1.15 coefficient truncation and the 14-bit arithmetic right-shift in the output scaling path — it is expected and acceptable for this coefficient set.

The overlay plot confirms the Verilog and MATLAB curves are visually indistinguishable, with the small integer-level RMSE only visible at the LSB level.

---

## How to run

**Simulation (Vivado xsim):**
```bash
# Copy stimulus file to sim/ directory first
cp your_stimulus_file.txt sim/simple_IIR_biquad_test_stimulus.txt
cd sim/
vivado -mode batch -source run_sim.tcl
```

**MATLAB verification:**
```matlab
% Copy filter_input.txt and filter_output.txt from sim/ to matlab/
cd matlab/
verify_iir_output
```

---

## Tools

| Tool | Version |
|---|---|
| Cadence Genus | 20.11-s111_1 |
| Vivado / xsim | 2022.x |
| MATLAB | R2023a or later |
| Standard cell library | Nominal PVT, enclosed wireload |