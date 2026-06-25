%% N-1 Contingency Analysis with Isolated Node Isolation & SOCP-OPF
clc;
clear all;

define_constants;

% 1. Load the base network
mpc_base = loadcase("case_ACTIVSg200");
mpc_base.bus(:, BUS_AREA) = mpc_base.bus(:, ZONE);
contab = contab_ACTIVSg200;

mpopt = mpoption('verbose', 0, 'out.all', 0);
mpopt_socp = mpoption(mpopt, 'model', 'AC', 'opf.ac.solver', 'MIPS');

contab_cases_example = [1:7, 241:245];
results = calc_mls(mpc_base, contab, contab_cases_example, 0.00, 1, mpopt, mpopt_socp);

results