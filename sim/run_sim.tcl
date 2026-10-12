# =============================================================================
# run_sim.tcl -- Vivado xsim simulation script for IIR Biquad DF-I testbench
#
# Usage (from Vivado Tcl Console or batch):
#   vivado -mode batch -source run_sim.tcl
#
# Or from within a Vivado project:
#   source sim/run_sim.tcl
# =============================================================================

# Compile RTL and testbench
xvlog ../rtl/simple_IIR_biquad_DF1.v
xvlog ../tb/simple_IIR_biquad_DF1_tb.v

# Elaborate
xelab simple_IIR_biquad_DF1_tb -debug typical -s iir_sim

# Run simulation — stimulus file must be in the directory where xsim is invoked
xsim iir_sim -runall

# Waveform dump is handled inside the testbench via $dumpfile/$dumpvars if needed.
# To open the waveform GUI after batch run:
#   xsim iir_sim --gui