define_constants;

mpc = loadcase('case_ACTIVSg200');
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);

if 0 == exist("risk_per_edge_for_graph.mat")
    warning('off');
    contab = contab_ACTIVSg200;
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    labels = unique(contab(:, CT_LABEL));   % 1..number of branches
    n_branches = size(mpc.branch, 1);
    for k = 1:n_branches
    risk = zeros(n_branches, 1);            % 1 = critical, 0 = safe
        mpc_k = apply_changes(k, mpc, contab);
        results_k = runpf(mpc_k, mpopt);
        risk(k) = ~results_k.success;
    end
    save("risk_per_edge_for_graph.mat", "risk");
    warning('on');
else
    risk = load("risk_per_edge_for_graph.mat").risk;
end

% Extract graph structure
f = mpc.branch(:, F_BUS);
t = mpc.branch(:, T_BUS);

% Build graph
G = graph(f, t);
[x y] = graph_get_coords(G);
[G x y] = graph_min_length(G, x, y, 0.5);

fig = figure;
h = plot(G, ...,
    'XData', x, ...
    'YData', y, ...
    'NodeColor', 'k', ...
    'MarkerSize', 5, ...
    'EdgeCData', risk, ...
    'EdgeColor', 'flat', ...,
    'EdgeAlpha', 0.7);

provide_network_design;
colormap(jet);

% title('ACTIVSg200 Network — N-1 Critical Lines Highlighted');

% Color edges by N-1 risk

% Make critical lines thicker
h.LineWidth = 1.25 * (1 + risk);

% print -dpng graph;
exportgraphics(fig, "Network_CLines.pdf");