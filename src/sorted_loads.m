%% Define the base case
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas

%% Load load scenarios
scenarios = scenarios_ACTIVSg200;           % a chgtab matrix, NOT a profile struct
contab = contab_ACTIVSg200;                 % the contingency table
sc_labels = unique(scenarios(:, CT_LABEL)); % list of hours
ct_labels = unique(contab(:, CT_LABEL));    % list of contingency IDs

% Generate a seeded sample of indices
rand("state", seed);
subsample = randi(rows(sc_labels), N, 1);
ct_total = numel(ct_labels);
result_mat = zeros(ct_total, N);

% apply loads
for j = 1:N
    mpc_t = apply_changes(sc_labels(subsample(j, 1)), mpc, scenarios);
    % disable components
    for k = 1:ct_total
        mpc_tk = apply_changes(ct_labels(k), mpc_t, contab);
        results_tk = runpf(mpc_tk, mpopt);
        result_mat(k, j) = (results_tk.success == 1);
    end
end

result = result_mat;
end