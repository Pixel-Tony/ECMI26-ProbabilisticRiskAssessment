% %% Define the base case
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
% contab = contab_ACTIVSg200;             % load the contingency table

% yearly_mls = load("yearly_mls_all_400_subsamples.mat").yearly_mls; %insert load
% %% Compute probabilities
% % first compute kV and set to 0 for transformers
% [~, fidx] = ismember(mpc.branch(:, F_BUS), mpc.bus(:, BUS_I));
% [~, tidx] = ismember(mpc.branch(:, T_BUS), mpc.bus(:, BUS_I));

% fkv = mpc.bus(fidx, BASE_KV);
% tkv = mpc.bus(tidx, BASE_KV);

% branch_kv = fkv;
% % separate transformers
% %branch_kv(fkv ~= tkv) = 0;

% %compute line lengths for non transformers
% lns = lengths(mpc);
% probabilities = zeros(numel(lns),1);

% % rescale line lengths such that median 115kV line has length 20km
% lns = lns * 20 / median(lns(branch_kv == 115));

% % compute probs based on data available online
% probabilities(branch_kv==115) = lns(branch_kv==115) * 0.01 * 100 / 8760;
% probabilities(branch_kv==230) = lns(branch_kv==230) * 0.01 * 7 / 8760;
% probabilities(branch_kv==13.8) = lns(branch_kv==13.8) * 0.07 * 7 / 8760;
% %probabilities(branch_kv==0) = 0.1 * 3 / 8760; %transformers
% % disp(probabilities)

% %% rescale MLS
% yearly_mls_statistical = yearly_mls .* probabilities;
% save("yearly_mls_statistical.mat", "yearly_mls_statistical");
yearly_mls_statistical = load("yearly_mls_statistical.mat").yearly_mls_statistical;

% disp(yearly_mls_statistical) % Note: units are MWh / year

%% plot network graph with mls heatmap
from_bus = mpc.branch(:, F_BUS);
to_bus   = mpc.branch(:, T_BUS);
bus_ids  = mpc.bus(:, BUS_I);

[~, s] = ismember(from_bus, bus_ids);
[~, t] = ismember(to_bus, bus_ids);

G = graph(s, t);
[x y] = graph_get_coords(G);
[G x y] = graph_min_length(G, x, y, 0.5);

edge_values = yearly_mls_statistical;   % nbranch x 1, same order as mpc.branch

% Nonzero edges
tol = 1e-6;
idx = abs(edge_values) > tol;

% Labels only for nonzero edges
edge_labels = strings(size(edge_values));
edge_labels(idx) = string(round(edge_values(idx), 2));

% Thicker nonzero edges
line_widths = 1.25 * ones(size(edge_values));
line_widths(idx) = 2.5;


f = figure;
p = plot(G, ...
    'XData', x, ...
    'YData', y, ...
    'NodeLabel', {}, ...
    'EdgeLabel', {}, ...
    'EdgeCData', edge_values, ...
    'LineWidth', line_widths, ...
    'Marker', 'o', ...
    'MarkerSize', 4);
colormap(turbo);
colorbar;

provide_network_design;

% ------------------------
% Highlight generator buses
% ------------------------
gen_bus_ids = unique(mpc.gen(:, GEN_BUS));
% Convert MATPOWER bus IDs to graph node indices
[~, gen_nodes] = ismember(gen_bus_ids, bus_ids);

highlight(p, gen_nodes, 'Marker', 'square', 'NodeColor', [1 0 0]);

% Heatmap of expected yearly MLS by line
exportgraphics(f, "Heatmap_E_MLS_by_line.pdf");