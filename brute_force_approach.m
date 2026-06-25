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

disp(yearly_mls)


%% non-trivial cases
n_scenarios_to_test = 20;   % change this as desired
rng('default')
rng(1); % optional, for repeatability
rand_idx = randperm(numel(scen_labels), n_scenarios_to_test);
selected_scenarios = scen_labels(rand_idx);

edge_ids = edges_generator_causes_failure(:);
mpopt_mls = mpoption(mpopt, 'model', 'AC', 'opf.ac.solver','MIPS');

for k = 1:numel(edge_ids)
    disp(k)
    edge_id = edge_ids(k);
    mpc_k = apply_changes(con_labels(edge_id), mpc, contab);
    
    load_sheds = zeros(1,numel(selected_scenarios));
    for t = 1:numel(selected_scenarios)
        mpc_kt = apply_changes(selected_scenarios(t),mpc_k, scenarios);
        result_kt = runopf(mpc_kt,mpopt_mls);
        original_loads = mpc_kt.bus(:,3);
        new_loads = result_kt.bus(:,3);
        load_diff = original_loads-new_loads;
        load_sheds(t) = sum(load_diff);
        disp(load_diff)
    end
    yearly_mls(edge_id) = yearly_mls(edge_id) + 8760*mean(load_sheds);
end

clc
disp(yearly_mls(edges_consumer_causes_failure))
disp('boi')
disp(yearly_mls(edges_generator_causes_failure))

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