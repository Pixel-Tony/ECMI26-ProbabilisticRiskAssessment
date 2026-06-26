define_constants;

mpc = loadcase('case_ACTIVSg200');
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);
contab = contab_ACTIVSg200;

mpopt = mpoption('verbose', 0, 'out.all', 0);

labels = unique(contab(:, CT_LABEL));
n_branches = size(mpc.branch, 1);

risk = zeros(n_branches, 1);

for k = 1:n_branches
    mpc_k = apply_changes(k, mpc, contab);
    results_k = runpf(mpc_k, mpopt);

    if results_k.success == 0
        risk(k) = 1;
    end
end

% Extract graph structure
f = mpc.branch(:, F_BUS);
t = mpc.branch(:, T_BUS);

% Identify generator buses
gen_buses = unique(mpc.gen(:, GEN_BUS));

% Build graph
G = graph(f, t);

figure;
h = plot(G, ...
    'Layout', 'force', ...
    'MarkerSize', 5, ...
    'EdgeAlpha', 0.8);

title('ACTIVSg200 — N-1 Critical Lines with Generator Differentiation');

%% ---------------- NODE COLORS ----------------
node_colors = repmat([0 0 0], size(mpc.bus,1), 1);   % normal buses = black
node_colors(gen_buses, :) = repmat([0 0.4 1], length(gen_buses), 1); % generators = blue
h.NodeColor = node_colors;

%% ---------------- EDGE COLORS ----------------
edge_colors = repmat([0.7 0.7 0.7], n_branches, 1); % safe = gray
edge_colors(risk==1, :) = repmat([1 0 0], sum(risk==1), 1); % critical = red

% Highlight critical edges connected to generators (orange)
critical_edges = find(risk == 1);
for i = critical_edges'
    if ismember(f(i), gen_buses) || ismember(t(i), gen_buses)
        edge_colors(i,:) = [1 0.5 0];   % orange
    end
end

h.EdgeColor = edge_colors;

% Line width
h.LineWidth = 0.5 + 3 * risk;

%% ---------------- LEGEND ----------------
hold on;

% Dummy plots for legend
plot(nan, nan, 'o', 'MarkerFaceColor', [0 0.4 1], 'MarkerEdgeColor','k', 'DisplayName','Generator Bus');
plot(nan, nan, 'o', 'MarkerFaceColor', [0 0 0], 'MarkerEdgeColor','k', 'DisplayName','Normal Bus');
plot(nan, nan, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 2, 'DisplayName','Safe Line');
plot(nan, nan, '-', 'Color', [1 0 0], 'LineWidth', 2, 'DisplayName','Critical Line (Blackout)');
plot(nan, nan, '-', 'Color', [1 0.5 0], 'LineWidth', 2, 'DisplayName','Critical Line Connected to Generator');

legend('Location','bestoutside');
hold off;
