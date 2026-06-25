function results = calc_mls(mpc, contab, contab_cases, allowance, verbose, mpopt, mpopt_socp)
%% N-1 Contingency Analysis with Isolated Node Isolation & SOCP-OPF
% use [] for contab_cases to use all cases, otherwise it should be a mask to choose specific cases

define_constants;

if verbose
    fprintf_verb = @(varargin) fprintf(varargin{:});
else
    fprintf_verb = @(varargin) 0;
end

Pmidpoint = mpc.gen(:, PG);
mpc.gen(:, PMAX) = Pmidpoint * (1 + allowance); % TODO rename allowance?
mpc.gen(:, PMIN) = Pmidpoint / (1 + allowance);

%Qmidpoint = mpc.gen(:, QMIN);
%mpc.gen(:, QMAX) = Qmidpoint;
%mpc.gen(:, QMIN) = Qmidpoint;

%%
if isequal(contab_cases, [])
    contab_cases = logical(ones(height(contab), 1));
end;
labels = unique(contab(contab_cases, CT_LABEL));
VOLL = 1e5;

%% Summary for each contab case
results = zeros(numel(labels), 2);

fprintf_verb('Starting real-time contingency screening with dynamic node isolation...\n');
tic;

STATUS_FEASIBLE = 0;            % Case was feasible
STATUS_ISOLATED_OPTIMIZED = 1;  % Unfeasible cases with isolated points that were successfully optimized
STATUS_NORMAL_OPTIMIZED = 2;    % Unfeasible cases (no isolated points) successfully optimized
STATUS_OPTIMIZED_FAILED = 3;    % Cases where optimization completely failed

for k = 1:numel(labels)
    fprintf_verb('\n--- Evaluating Contingency %d / %d ---\n', k, numel(labels));

    mpc_k = apply_changes(labels(k), mpc, contab);
    PD_nom = mpc_k.bus(:, PD);
    total_nominal_load = sum(PD_nom);

    % ---------------------------------------------------------------------
    % STEP 1: Baseline Screening via Standard Power Flow
    % ---------------------------------------------------------------------
    results_pf = runpf(mpc_k, mpopt);

    if results_pf.success == 1
        fprintf_verb('  System Status: FEASIBLE baseline. 0 MW shedding required.\n');
        continue;
    end

    % Else, system is unfeasible. Check for isolated nodes to modify topology.
    fprintf_verb('  System Status: UNFEASIBLE. Analyzing topology...\n');

    % Identify active connected lines
    active_branches = (mpc_k.branch(:, BR_STATUS) > 0);
    connected_buses = unique([mpc_k.branch(active_branches, F_BUS); ...
                                mpc_k.branch(active_branches, T_BUS)]);

    all_buses = mpc_k.bus(:, BUS_I);
    isolated_buses = setdiff(all_buses, connected_buses);

    has_isolated_bus = ~isempty(isolated_buses);

    % Clone the contingency case for modification
    mpc_mod = mpc_k;

    if has_isolated_bus
        fprintf_verb('    -> Isolated buses detected: %s\n', mat2str(isolated_buses'));
        fprintf_verb('    -> Modifying network matrix to mathematically drop isolated nodes...\n');

        % Map bus IDs to their row indices in the MATPOWER matrix
        for b_id = isolated_buses'
            bus_idx = find(mpc_mod.bus(:, BUS_I) == b_id);
            if ~isempty(bus_idx)
                mpc_mod.bus(bus_idx, BUS_TYPE) = 4; % Mark bus as type 4 (Isolated/Out-of-service)
                mpc_mod.bus(bus_idx, PD) = 0;       % Drop active load from optimization space
                mpc_mod.bus(bus_idx, QD) = 0;       % Drop reactive load from optimization space
            end
        end
    end

    % ---------------------------------------------------------------------
    % STEP 2: Optimize the modified/cleaned grid structure
    % ---------------------------------------------------------------------
    % Convert the remaining static loads to dispatchable loads
    mpc_socp = load2disp(mpc_mod);
    disp_load_idx = find(isload(mpc_socp.gen));

    % Set linear penalty cost for shedding viable load
    mpc_socp.gencost(disp_load_idx, MODEL) = POLYNOMIAL;
    mpc_socp.gencost(disp_load_idx, NCOST) = 2;
    mpc_socp.gencost(disp_load_idx, COST)   = VOLL;
    mpc_socp.gencost(disp_load_idx, COST + 1) = 0;

    % Run the Convex Optimization
    results_socp = runopf(mpc_socp, mpopt_socp);

    if ~results_socp.success
        fprintf_verb('  [SOCP-OPF]   : FAILED to resolve numerical boundaries even after isolation.\n');
        results(k, 1) = STATUS_OPTIMIZED_FAILED;
        continue
    end

    P_nominal_disp = mpc_socp.gen(disp_load_idx, PMIN);
    P_optimized_disp = results_socp.gen(disp_load_idx, PG);
    load_shed_vector = P_nominal_disp - P_optimized_disp;

    load_shed_vector(load_shed_vector < 1e-3) = 0;
    total_cut = sum(load_shed_vector);

    % Account for the power automatically shed from isolating the floating node
    if has_isolated_bus
        isolated_indices = mpc_k.bus(:, BUS_TYPE) == 4 | ismember(mpc_k.bus(:, BUS_I), isolated_buses);
        forced_cut = sum(mpc_k.bus(isolated_indices, PD));
        total_cut = total_cut + forced_cut;

        fprintf_verb('  [SOCP-OPF]   : OPTIMIZED SUCCESSFULLY (Isolated nodes excluded)\n');
        results(k, 1) = STATUS_ISOLATED_OPTIMIZED;
    else
        fprintf_verb('  [SOCP-OPF]   : OPTIMIZED SUCCESSFULLY (Standard network)\n');
        results(k, 1) = STATUS_NORMAL_OPTIMIZED;
    end

    pct_shed = (total_cut / total_nominal_load) * 100;
    fprintf_verb('  Load Shedding: %.2f MW (%.2f%% dropped total)\n', total_cut, pct_shed);
    results(k, 2) = pct_shed;
end

% =========================================================================
% FINAL STATISTICAL BREAKDOWN SUMMARY
% =========================================================================
if verbose
    fprintf_verb("\n==================================================\n" ...
               + "SCREENING EXECUTION SUMMARY\n" ...
               + "==================================================\n" ...
               + "1. Feasible Baseline Cases              : %d\n" ...
               + "2. Unfeasible Cases Optimized with Node Isolation : %d\n" ...
               + "3. Unfeasible Cases Optimized Normally            : %d\n" ...
               + "4. Failed Optimizations                 : %d\n" ...
               + "--------------------------------------------------\n" ...
               + "Total processing screening time         : %.3f seconds\n" ...
               + "==================================================\n'", ...
               sum(results(:, 1) == STATUS_FEASIBLE), ...
               sum(results(:, 1) == STATUS_ISOLATED_OPTIMIZED), ...
               sum(results(:, 1) == STATUS_NORMAL_OPTIMIZED), ...
               sum(results(:, 1) == STATUS_OPTIMIZED_FAILED), ...
               toc);
end

end