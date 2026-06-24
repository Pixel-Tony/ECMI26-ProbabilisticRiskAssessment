%% N-1 Contingency Analysis with Isolated Node Isolation & SOCP-OPF
clc;
clear all;

define_constants;

% 1. Load the base network
mpc_base = loadcase("case_ACTIVSg200");      
mpc_base.bus(:, BUS_AREA) = mpc_base.bus(:, ZONE);
contab = contab_ACTIVSg200;   

Pmidpoint = mpc_base.gen(:, PG);
mpc_base.gen(:, PMAX) = Pmidpoint;
mpc_base.gen(:, PMIN) = Pmidpoint;

%Qmidpoint = mpc_base.gen(:, QMIN);
%mpc_base.gen(:, QMAX) = Qmidpoint;
%mpc_base.gen(:, QMIN) = Qmidpoint;


mpopt = mpoption('verbose', 0, 'out.all', 0);
mpopt_socp = mpoption(mpopt, 'model', 'AC', 'opf.ac.solver', 'MIPS');

%%
labels = unique(contab(:, CT_LABEL));   
VOLL = 1e5; 

% --- Counters for Final Summary ---
count_feasible = 0;
count_isolated_optimized = 0;  % Unfeasible cases with isolated points that were successfully optimized
count_normal_optimized = 0;    % Unfeasible cases (no isolated points) successfully optimized
count_optimized_failed = 0;    % Cases where optimization completely failed

fprintf('Starting real-time contingency screening with dynamic node isolation...\n');
tic;

for k = 1:numel(labels)
    fprintf('\n--- Evaluating Contingency %d ---\n', k);
    
    mpc_k = apply_changes(labels(k), mpc_base, contab);
    PD_nom = mpc_k.bus(:, PD);
    total_nominal_load = sum(PD_nom);

    % ---------------------------------------------------------------------
    % STEP 1: Baseline Screening via Standard Power Flow
    % ---------------------------------------------------------------------
    results_pf = runpf(mpc_k, mpopt);
    
    if results_pf.success == 1
        fprintf('  System Status: FEASIBLE baseline. 0 MW shedding required.\n');
        count_feasible = count_feasible + 1;
        
    else
        % System is unfeasible. Check for isolated nodes to modify topology.
        fprintf('  System Status: UNFEASIBLE. Analyzing topology...\n');
        
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
            fprintf('    -> Isolated buses detected: %s\n', mat2str(isolated_buses'));
            fprintf('    -> Modifying network matrix to mathematically drop isolated nodes...\n');
            
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
        mpc_socp.gencost(disp_load_idx, COST+1) = 0;
        
        % Run the Convex Optimization
        results_socp = runopf(mpc_socp, mpopt_socp);
        
        if results_socp.success == 1
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
            end
            
            pct_shed = (total_cut / total_nominal_load) * 100;
            
            if has_isolated_bus
                fprintf('  [SOCP-OPF]   : OPTIMIZED SUCCESSFULLY (Isolated nodes excluded)\n');
                count_isolated_optimized = count_isolated_optimized + 1;
            else
                fprintf('  [SOCP-OPF]   : OPTIMIZED SUCCESSFULLY (Standard network)\n');
                count_normal_optimized = count_normal_optimized + 1;
            end
            fprintf('  Load Shedding: %.2f MW (%.2f%% dropped total)\n', total_cut, pct_shed);
        else
            fprintf('  [SOCP-OPF]   : FAILED to resolve numerical boundaries even after isolation.\n');
            count_optimized_failed = count_optimized_failed + 1;
        end
    end
end

% =========================================================================
% FINAL STATISTICAL BREAKDOWN SUMMARY
% =========================================================================
fprintf('\n==================================================\n');
fprintf('SCREENING EXECUTION SUMMARY\n');
fprintf('==================================================\n');
fprintf('1. Feasible Baseline Cases              : %d\n', count_feasible);
fprintf('2. Unfeasible Cases Optimized with Node Isolation : %d\n', count_isolated_optimized);
fprintf('3. Unfeasible Cases Optimized Normally            : %d\n', count_normal_optimized);
fprintf('4. Failed Optimizations                 : %d\n', count_optimized_failed);
fprintf('--------------------------------------------------\n');
fprintf('Total processing screening time         : %.3f seconds\n', toc);
fprintf('==================================================\n');

%%
printpf(results_socp);
