%% Define the base case
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
contab = contab_ACTIVSg200;             % load the contingency table

% set options: silence matpower output
mpopt = mpoption('verbose', 0, 'out.all', 0); % set verbose to 1 to obtain output for all cases

yearly_mls = %insert load
%% Compute probabilities
% first compute kV and set to 0 for transformers
[~, fidx] = ismember(mpc.branch(:, F_BUS), mpc.bus(:, BUS_I));
[~, tidx] = ismember(mpc.branch(:, T_BUS), mpc.bus(:, BUS_I));

fkv = mpc.bus(fidx, BASE_KV);
tkv = mpc.bus(tidx, BASE_KV);

branch_kv = fkv;
% separate transformers
%branch_kv(fkv ~= tkv) = 0;

%compute line lengths for non transformers
lengths = (branch_kv.^2) .* hypot(mpc.branch(:,BR_R), mpc.branch(:, BR_X));
probabilities = zeros(numel(lengths),1);

% rescale line lengths such that median 115kV line has length 20km
length_factor = 20/median(lengths(branch_kv==115));
lengths = lengths * length_factor;

% compute probs based on data available online
probabilities(branch_kv==115) = lengths(branch_kv==115) * 0.01 * 100 / 8760;
probabilities(branch_kv==230) = lengths(branch_kv==230) * 0.01 * 7 / 8760;
probabilities(branch_kv==13.8) = lengths(branch_kv==13.8) * 0.07 * 7 / 8760;
%probabilities(branch_kv==0) = 0.1 * 3 / 8760; %transformers
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

tmp = plot(G, 'Layout', 'force', 'Visible', 'off');
x = tmp.XData;
y = tmp.YData;
delete(tmp);

% Enforce minimum edge length
min_len = 0.5;   % adjust this

for iter = 1:200
    for e = 1:numedges(G)
        i = G.Edges.EndNodes(e,1);
        j = G.Edges.EndNodes(e,2);

        dx = x(j) - x(i);
        dy = y(j) - y(i);
        d = hypot(dx, dy);

        if d < min_len && d > 0
            push = 0.5 * (min_len - d);
            ux = dx / d;
            uy = dy / d;

            x(i) = x(i) - push * ux;
            y(i) = y(i) - push * uy;
            x(j) = x(j) + push * ux;
            y(j) = y(j) + push * uy;
        end
    end
end

figure;
p = plot(G, ...
    'XData', x, ...
    'YData', y, ...
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

title('Heatmap of expected yearly MLS by line');

%% histogram plot
hist(yearly_mls_statistical(yearly_mls_statistical~=0))
title('Histogram of expected yearly MLS by line')
euro=char(8364);
ylabel({'Price',euro})