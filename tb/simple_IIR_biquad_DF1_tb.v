// =============================================================================
// Module      : simple_IIR_biquad_DF1_tb
// Description : Testbench for the IIR Biquad DF-I filter.
//
//               Stimulus is read from a text file (one integer sample per line)
//               and driven into the DUT at 10 MHz (100 ns period). Filtered
//               output is logged to a separate text file for post-simulation
//               analysis in MATLAB.
//
// Verification approach:
//   1. Read up to 1000 samples from stimulus file into on-chip memory
//   2. Apply synchronous reset for 2 clock cycles
//   3. Drive samples on negedge to ensure setup time at posedge
//   4. Log both input and output to text files
//   5. Cross-check output against MATLAB reference (RMSE = 5.174657)
//
// File dependencies:
//   Input  : simple_IIR_biquad_test_stimulus.txt  (integer samples, one per line)
//   Output : filter_input.txt, filter_output.txt   (logged during simulation)
//
// Tool: Vivado xsim / Cadence Xcelium
// =============================================================================
`timescale 1ns/1ps

module simple_IIR_biquad_DF1_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg              clk;
    reg              rst;
    reg  signed [15:0] r_din;
    wire signed [15:0] dout;

    // 10 MHz clock: 50 ns half-period
    always #50 clk = ~clk;

    // -------------------------------------------------------------------------
    // File handles and simulation variables
    // -------------------------------------------------------------------------
    integer fid;               // stimulus file handle
    integer input_log_file;    // log file for driven input samples
    integer output_log_file;   // log file for DUT output samples
    integer status;            // $fscanf return value
    integer sample;            // temporary sample read variable
    integer i;                 // loop index

    localparam integer NUM_SAMPLES = 1000;

    // On-chip memory to store all stimulus before driving begins
    // (avoids file I/O timing issues during simulation)
    reg signed [15:0] r_wave_sample [0:NUM_SAMPLES-1];

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    simple_IIR_biquad_DF1 uut (
        .clk  (clk),
        .rst  (rst),
        .din  (r_din),
        .dout (dout)
    );

    // -------------------------------------------------------------------------
    // Main stimulus block
    // -------------------------------------------------------------------------
    initial begin

        // --- Initialise signals ---
        clk   = 0;
        r_din = 0;
        rst   = 1;

        // --- Open log files ---
        input_log_file = $fopen("filter_input.txt", "w");
        if (input_log_file == 0)
            $display("ERROR: Could not open filter_input.txt for writing");

        output_log_file = $fopen("filter_output.txt", "w");
        if (output_log_file == 0)
            $display("ERROR: Could not open filter_output.txt for writing");

        // --- Open stimulus file ---
        // Update this path to point to your stimulus file location.
        // For Vivado xsim: use the project simulation directory or a relative path.
        // For Xcelium: relative paths resolve from the sim/ run directory.
        fid = $fopen("simple_IIR_biquad_test_stimulus.txt", "r");
        if (fid == 0) begin
            $display("ERROR: Could not open stimulus file.");
            $display("Ensure simple_IIR_biquad_test_stimulus.txt is in the simulation run directory.");
            $finish;
        end else begin
            $display("INFO: Stimulus file opened successfully.");
        end

        // --- Read stimulus into memory ---
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            status = $fscanf(fid, "%d\n", sample);
            if (status != 1) begin
                $display("INFO: End of stimulus file at sample %0d. Padding remainder with 0.", i);
                sample = 0;
            end
            r_wave_sample[i] = sample[15:0];
        end
        $fclose(fid);

        // --- Apply and release synchronous reset ---
        #200;       // hold reset for 2 clock cycles (200 ns at 10 MHz)
        rst = 0;

        // --- Drive stimulus samples ---
        // Samples are driven on negedge to ensure valid data at the next posedge.
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(negedge clk);
            r_din = r_wave_sample[i];
        end

        // --- Allow pipeline to flush ---
        @(negedge clk);
        #1000;

        // --- Close logs and end simulation ---
        $fclose(input_log_file);
        $fclose(output_log_file);
        $display("INFO: Simulation complete. Output written to filter_output.txt");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Logging block: write input and output to file on every active clock edge
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            $fwrite(input_log_file,  "%d\n", r_din);
            $fwrite(output_log_file, "%d\n", dout);
            $fflush(input_log_file);
            $fflush(output_log_file);
        end
    end

endmodule