%% Define the base case
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
contab = contab_ACTIVSg200;             % load the contingency table

% set options: silence matpower output
mpopt = mpoption('verbose', 0, 'out.all', 0); % set verbose to 1 to obtain output for all cases

%% Identify cases where there are failures, and sort by trivial and  nontrivial
% apply the contingencies one by one
clc
con_labels = unique(contab(:, CT_LABEL));   % list of contingency IDs
converged = 0;

nodes_consumer_causes_failure = [];
edges_consumer_causes_failure = [];
nodes_generator_causes_failure = [];
edges_generator_causes_failure = [];


for k = 1:numel(con_labels)
    clc
    disp(k)
    mpc_k   = apply_changes(con_labels(k), mpc, contab);

    % run power flow computation
    results_k = runpf(mpc_k, mpopt);             
    if results_k.success == 1
        % converged
        % ... collect results ...
        converged = converged + 1;
    else
        leaf_bus = leaf_bus_of_branch(mpc, con_labels(k));
        if mpc.bus(leaf_bus,2) == 1
            nodes_consumer_causes_failure = [nodes_consumer_causes_failure, leaf_bus];
            edges_consumer_causes_failure = [edges_consumer_causes_failure, k];
        else
            nodes_generator_causes_failure = [nodes_generator_causes_failure, leaf_bus];
            edges_generator_causes_failure = [edges_generator_causes_failure, k];
        end
    end
end

%% Trivial cases
yearly_mls = zeros(numel(con_labels),1); % table of edges and their yearly total mls

scenarios = scenarios_ACTIVSg200;          % a chgtab matrix, NOT a profile struct

% each distinct label = one load scenario / time sample
scen_labels = unique(scenarios(:, CT_LABEL));

node_ids = nodes_consumer_causes_failure(:);
edge_ids = edges_consumer_causes_failure(:);

for t = 1:numel(scen_labels)
    mpc_t = apply_changes(scen_labels(t), mpc, scenarios);

    % bus(:,3) is load column
    yearly_mls(edge_ids) = yearly_mls(edge_ids) + mpc_t.bus(node_ids, 3);
end

%% Nontrivial_cases
contab_new = contab(edges_generator_causes_failure,:);

rng('default');
rng(1);

n_subsamples = 400;
scenarios = scenarios_ACTIVSg200;
scen_labels = unique(scenarios(:, CT_LABEL));
rand_idx = randperm(numel(scen_labels), n_subsamples);
selected_scenarios = scen_labels(rand_idx);

mpopt_mls = mpoption(mpopt, 'model', 'AC', 'opf.ac.solver','MIPS');

mls_sum = zeros(numel(edges_generator_causes_failure),1);
%mls_data = zeros(1,n_subsamples);
for t = 1:numel(selected_scenarios)
    disp(t)
    mpc_t = apply_changes(selected_scenarios(t),mpc, scenarios);
    results_t = calc_mls(mpc_t, contab_new, 0.02, 0, mpopt, mpopt_mls);
    mls_t = results_t(:,3);
    %mls_data(:,t) = mls_t;
    mls_sum = mls_sum + mls_t;
end

yearly_mls_generators = 8760 * mls_sum / n_subsamples;
yearly_mls(edges_generator_causes_failure) = yearly_mls_generators;
disp(yearly_mls)
%monte_carlo_estimate = cumsum(mls_data,2) ./ (1:size(mls_data,2));
%plot(monte_carlo_estimate);

%% Compute probabilities
% first compute kV and set to 0 for transformers
[~, fidx] = ismember(mpc.branch(:, F_BUS), mpc.bus(:, BUS_I));
[~, tidx] = ismember(mpc.branch(:, T_BUS), mpc.bus(:, BUS_I));

fkv = mpc.bus(fidx, BASE_KV);
tkv = mpc.bus(tidx, BASE_KV);

branch_kv = fkv;
% separate transformers
branch_kv(fkv ~= tkv) = 0;

%compute line lengths for non transformers
lengths = branch_kv .* hypot(mpc.branch(:,BR_R), mpc.branch(:, BR_X));
probabilities = zeros(numel(lengths),1);

% rescale line lengths such that median 115kV line has length 20km
length_factor = 20/median(lengths(branch_kv==115));
lengths = lengths * length_factor;

% compute probs based on data available online
probabilities(branch_kv==115) = lengths(branch_kv==115) * 0.01 * 100 / 8760;
probabilities(branch_kv==230) = lengths(branch_kv==230) * 0.01 * 7 / 8760;
probabilities(branch_kv==0) = 0.1 * 3 / 8760; %transformers
disp(probabilities)

%% rescale MLS
yearly_mls_statistical = yearly_mls .* probabilities;
disp(yearly_mls_statistical) % Note: units are MWh / year

%% plot network graph with mls heatmap
from_bus = mpc.branch(:, F_BUS);
to_bus   = mpc.branch(:, T_BUS);
bus_ids  = mpc.bus(:, BUS_I);

[~, s] = ismember(from_bus, bus_ids);
[~, t] = ismember(to_bus, bus_ids);

G = graph(s, t);

edge_values = yearly_mls_statistical;   % nbranch x 1, same order as mpc.branch

% Nonzero edges
tol = 1e-6;
idx = abs(edge_values) > tol;

% Labels only for nonzero edges
edge_labels = strings(size(edge_values));
edge_labels(idx) = string(round(edge_values(idx), 2));

% Thicker nonzero edges
line_widths = 0.5 * ones(size(edge_values));
line_widths(idx) = 3;

figure;
p = plot(G, ...
    'Layout', 'force', ...
    'NodeLabel', {}, ...
    'EdgeLabel', {}, ...
    'EdgeCData', edge_values, ...
    'LineWidth', line_widths, ...
    'MarkerSize', 3);

colormap(turbo);
colorbar;

% ------------------------
% Highlight generator buses
% ------------------------
gen_bus_ids = unique(mpc.gen(:, GEN_BUS));

% Convert MATPOWER bus IDs to graph node indices
[~, gen_nodes] = ismember(gen_bus_ids, bus_ids);

highlight(p, gen_nodes, ...
    'NodeColor', [1 0 0], ...    % red
    'MarkerSize', 2);

title('Grid edge heatmap with generator buses');
%% Functions

function bus = leaf_bus_of_branch(mpc, br_idx)
    f = mpc.branch(br_idx, 1);
    t = mpc.branch(br_idx, 2);

    all_buses = mpc.branch(:, 1:2);

    f_count = sum(all_buses(:) == f);
    t_count = sum(all_buses(:) == t);

    if f_count == 1 && t_count > 1
        bus = f;
    elseif t_count == 1 && f_count > 1
        bus = t;
    else
        error('Expected precisely one endpoint to have no other branches.');
    end
end

function results = calc_mls(mpc, contab, allowed_generation_variation, verbose, mpopt, mpopt_socp, weights)
%% N-1 Contingency Analysis with Isolated Node Isolation & SOCP-OPF
% use [] for contab_cases to use all cases, otherwise it should be a mask to choose specific cases

define_constants;

if verbose
    fprintf_verb = @(varargin) fprintf(varargin{:});
else
    fprintf_verb = @(varargin) 0;
end

P_ref = mpc.gen(:, PG);         % Generator dispatch from input data
PMIN_ref = mpc.gen(:, PMIN);    % Original lower bounds
PMAX_ref = mpc.gen(:, PMAX);    % Original upper bounds

Pmidpoint = mpc.gen(:, PG);
mpc.gen(:, PMAX) = Pmidpoint * (1 + allowed_generation_variation);
mpc.gen(:, PMIN) = Pmidpoint * (1 - allowed_generation_variation);

mpc.gencost(:, 1) = 2;      % polynomial model
mpc.gencost(:, 2:3) = 0;    % startup and shutdown costs
mpc.gencost(:, 4) = 2;      % two coefficients: c1, c0
mpc.gencost(:, 5:6) = 0;    % zero linear and constant coefficients

%%
%if isequal(contab_cases, [])
%    contab_cases = logical(ones(height(contab), 1));
%end;
%labels = unique(contab(contab_cases, CT_LABEL));

labels = unique(contab(:, CT_LABEL));
VOLL = 1; %1e5;

%% Summary for each contab case
results = zeros(numel(labels), 3);

fprintf_verb('Starting real-time contingency screening with dynamic node isolation...\n');
tic;

STATUS_FEASIBLE = 0;            % Case was feasible
STATUS_ISOLATED_OPTIMIZED = 1;  % Unfeasible cases with isolated points that were successfully optimized
STATUS_NORMAL_OPTIMIZED = 2;    % Unfeasible cases (no isolated points) successfully optimized
STATUS_OPTIMIZED_FAILED = 3;    % Cases where optimization completely failed

%%
w = weights;
%%
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
    if has_isolated_bus
        isolated_indices = mpc_k.bus(:, BUS_TYPE) == 4 | ismember(mpc_k.bus(:, BUS_I), isolated_buses);
        forced_cut = sum(mpc_k.bus(isolated_indices, PD));
    end

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
    mpc_socp.gencost(disp_load_idx, COST) = VOLL * w(disp_load_idx);
    mpc_socp.gencost(disp_load_idx, COST + 1) = 0;
    P_nominal = abs(mpc_socp.gen(disp_load_idx, PMIN));

    % Run the Convex Optimization
    results_socp = runopf(mpc_socp, mpopt_socp);
    if results_socp.success
        P_optimized = abs(results_socp.gen(disp_load_idx, PG));
        results(k, 3) = sum(P_nominal - P_optimized);
        if has_isolated_bus
            results(k, 3) = results(k, 3) + forced_cut;
        end
    else
        fprintf_verb(['  [SOCP-OPF]   : First attempt failed. ' ...
                      'Retrying with original PMIN/PMAX and redispatch penalty...\n']);

        % Start from the cleaned contingency topology, before load2disp()
        mpc_retry = mpc_mod;

        % Restore original generator bounds.
        % This assumes generator row order is unchanged by apply_changes().
        n_original_gen = size(mpc_retry.gen, 1);
        mpc_retry.gen(:, PMIN) = PMIN_ref(1:n_original_gen);
        mpc_retry.gen(:, PMAX) = PMAX_ref(1:n_original_gen);

        % Re-create dispatchable loads for the retry case
        mpc_retry = load2disp(mpc_retry);
        disp_load_idx_retry = find(isload(mpc_retry.gen));

        % Preserve the high cost for load shedding
        mpc_retry.gencost(disp_load_idx_retry, MODEL) = POLYNOMIAL;
        mpc_retry.gencost(disp_load_idx_retry, NCOST) = 2;
        mpc_retry.gencost(disp_load_idx_retry, COST) = VOLL;
        mpc_retry.gencost(disp_load_idx_retry, COST + 1) = 0;

        % The original generators are the rows present before load2disp().
        % load2disp() appends dispatchable loads after these rows.
        actual_gen_idx = 1:n_original_gen;

        lambda = 10;  % tune this

        for g = actual_gen_idx
            Pg_ref = P_ref(g);

            mpc_retry.gencost(g, MODEL) = POLYNOMIAL;
            mpc_retry.gencost(g, NCOST) = 3;

            mpc_retry.gencost(g, COST) = lambda;
            mpc_retry.gencost(g, COST + 1) = -2 * lambda * Pg_ref;
            mpc_retry.gencost(g, COST + 2) = lambda * Pg_ref^2;
        end

        % Second OPF attempt
        results_socp = runopf(mpc_retry, mpopt_socp);

        if ~results_socp.success
            fprintf_verb(['  [SOCP-OPF]   : Retry failed even with restored ' ...
                          'generator bounds.\n']);
            results(k, 1) = STATUS_OPTIMIZED_FAILED;
            continue;
        end

        % Use the retry model below when calculating load shedding
        mpc_socp = mpc_retry;

        fprintf_verb('  [SOCP-OPF]   : Retry succeeded with redispatch penalty.\n');

        P_optimized = abs(results_socp.gen(disp_load_idx, PG));
        if has_isolated_bus
            results(k, 3) = sum(P_nominal - P_optimized) + forced_cut;
        else
            results(k, 3) = sum(P_nominal - P_optimized);
        end
        disp_load_idx = disp_load_idx_retry;
    end

    P_nominal_disp = abs(mpc_socp.gen(disp_load_idx, PG));
    P_optimized_disp = abs(results_socp.gen(disp_load_idx, PG));
    load_shed_vector = P_nominal_disp - P_optimized_disp;

    load_shed_vector(load_shed_vector < 1e-3) = 0;
    total_cut = sum(load_shed_vector);

    % Account for the power automatically shed from isolating the floating node
    if has_isolated_bus
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
end