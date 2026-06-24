define_constants;

mpc = loadcase('case_ACTIVSg200');
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);
contab = contab_ACTIVSg200;

mpopt = mpoption('verbose', 0, 'out.all', 0);

labels = unique(contab(:, CT_LABEL));   % 1..number of branches
n_branches = size(mpc.branch, 1);
risk = zeros(n_branches, 1);            % 1 = critical, 0 = safe

warning('off');
for k = 1:n_branches
    mpc_k = apply_changes(k, mpc, contab);
    results_k = runpf(mpc_k, mpopt);
    risk(k) = ~results_k.success;
end
warning('on');

% Extract graph structure
f = mpc.branch(:, F_BUS);
t = mpc.branch(:, T_BUS);

% Build graph
G = graph(f, t);

fig = figure;
h = plot(G, ...
    'Layout', 'force', ...
    'NodeColor', 'k', ...
    'MarkerSize', 3, ...
    'EdgeAlpha', 0.8);

title('ACTIVSg200 Network — N-1 Critical Lines Highlighted');

% Color edges by N-1 risk
colormap(jet);
h.EdgeCData = risk;

colorbar;
ylabel(colorbar, 'N-1 Failure Risk');

% Make critical lines thicker
h.LineWidth = 0.5 + 4 * risk;

print -dpng graph;