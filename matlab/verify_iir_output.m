% =============================================================================
% verify_iir_output.m
% Description : MATLAB script to cross-check Verilog simulation output
%               against a floating-point IIR reference using the same
%               fixed-point coefficients.
%
% Usage:
%   1. Run the Verilog simulation to generate filter_input.txt and
%      filter_output.txt in the sim/ directory.
%   2. Copy both files to the same directory as this script (or update paths).
%   3. Run this script in MATLAB.
%
% Expected result: RMSE ≈ 5.17 (quantisation error from Q1.15 fixed-point)
% =============================================================================

clear; clc; close all;

% --- Load simulation data ---
verilog_input  = load('filter_input.txt');
verilog_output = load('filter_output.txt');

% --- Fixed-point coefficients (Q1.15, same as Verilog localparam values) ---
SCALE = 2^15;   % = 32768
b0 =  167 / SCALE;
b1 = -302 / SCALE;
b2 =  167 / SCALE;
a1 = -31881 / SCALE;  % stored as negative magnitude in RTL
a2 =  15531 / SCALE;

% --- MATLAB floating-point reference filter ---
% Transfer function: H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)
b_coeffs = [b0, b1, b2];
a_coeffs = [1, a1, a2];

matlab_output = filter(b_coeffs, a_coeffs, double(verilog_input));

% --- Compute RMSE ---
min_len = min(length(verilog_output), length(matlab_output));
rmse = sqrt(mean((verilog_output(1:min_len) - matlab_output(1:min_len)).^2));
fprintf('RMSE (Verilog vs MATLAB): %.6f\n', rmse);

% --- Plot ---
figure('Name', 'IIR Biquad DF-I Verification');

subplot(2,2,1);
plot(verilog_input, 'b');
title('Input signal (from stimulus file)');
xlabel('Sample'); ylabel('Amplitude (integer)');

subplot(2,2,2);
plot(matlab_output, 'r');
title('MATLAB reference output (floating-point)');
xlabel('Sample'); ylabel('Amplitude (float)');

subplot(2,2,3);
plot(verilog_output, 'b');
title('Verilog filter output');
xlabel('Sample'); ylabel('Amplitude (integer)');

subplot(2,2,4);
plot(verilog_output(1:min_len), 'b', 'DisplayName', 'Verilog output'); hold on;
plot(matlab_output(1:min_len),  'r--', 'DisplayName', 'MATLAB output');
title(sprintf('Overlay: Verilog vs MATLAB (RMSE = %.6f)', rmse));
xlabel('Sample'); ylabel('Amplitude');
legend('show');

fprintf('Done. Check figure for overlay comparison.\n');