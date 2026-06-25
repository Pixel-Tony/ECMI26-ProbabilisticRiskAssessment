%% Define the base case
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
contab = contab_ACTIVSg200;             % load the contingency table

% set options: silence matpower output
mpopt = mpoption('verbose', 0, 'out.all', 0); % set verbose to 1 to obtain output for all cases

%% Identify cases where there are failures
% apply the contingencies one by one
clc
con_labels = unique(contab(:, CT_LABEL));   % list of contingency IDs
converged = 0;

nodes_causing_failure = [];
edges_causing_failure = [];


for k = 1:numel(con_labels)
    clc
    disp(k)
    mpc_k   = apply_changes(con_labels(k), mpc, contab);

    % run power flow computation
    results_k = runpf(mpc_k, mpopt);             
    if results_k.success == 0
        leaf_bus = leaf_bus_of_branch(mpc, con_labels(k));
        nodes_causing_failure = [nodes_causing_failure, leaf_bus];
        edges_causing_failure = [edges_causing_failure, k];
    end
end

disp(numel(edges_causing_failure))
disp(numel(nodes_causing_failure))
disp('BOI')

%% Compute yearly costs
rng('default');
rng(1);

n_subsamples = 10;
scenarios = scenarios_ACTIVSg200;
scen_labels = unique(scenarios(:, CT_LABEL));
rand_idx = randperm(numel(scen_labels), n_subsamples);
selected_scenarios = scen_labels(rand_idx);

edge_ids = edges_causing_failure(:);
mpopt_cost = mpoption(mpopt, 'model', 'AC', 'opf.ac.solver','MIPS');

yearly_costs = zeros(numel(con_labels),1);

for k = 1:numel(edge_ids)
    disp(k)
    edge_id = edge_ids(k);
    mpc_k = apply_changes(con_labels(edge_id), mpc, contab);
    
    yearly_cost_k = 0;
    for t = 1:numel(selected_scenarios)
        mpc_kt = apply_changes(selected_scenarios(t),mpc_k, scenarios);
        result_kt = runopf(mpc_kt,mpopt_cost);
        yearly_cost_k = yearly_cost_k + result_kt.f;
    end
    yearly_cost_k = 8760 * yearly_cost_k / n_subsamples;
    yearly_costs(edge_id) = yearly_costs(edge_id) + yearly_cost_k;
end

disp(yearly_costs)
disp('boi1')
disp(yearly_costs(edges_causing_failure))
disp('boi2')
disp(yearly_costs(setdiff(1:length(yearly_costs), edges_causing_failure)))

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