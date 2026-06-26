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

% contab_cases_example = [1:7, 241:245];
on_weighting = true;
results = calc_mls(mpc_base, contab, [1:244], 0.00, 0, mpopt, mpopt_socp, on_weighting);

res_weighted = results(:, 3);

on_weighting = false;
results = calc_mls(mpc_base, contab, [1:244], 0.00, 0, mpopt, mpopt_socp, on_weighting);

res_non_weighted = results(:, 3);

res = [res_weighted, res_non_weighted];
res