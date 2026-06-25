define_constants;

mpc = loadcase('case_ACTIVSg200');
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);
contab = contab_ACTIVSg200;
chgtab = scenarios_ACTIVSg200();

mpopt = mpoption('verbose', 0, 'out.all', 0);

n_branches = size(mpc.branch, 1);

disp(n_branches)

risk = zeros(n_branches, 1);            % 1 = critical, 0 = safe

%create different frames
%min overall
minLoad = min(chgtab(:,7));
chgtab_block_min = chgtab(1:6,:);
chgtab_block_min(:,7) = minLoad;
%min per zone
[G, zone] = findgroups(chgtab(:,4));
minLoadperZone = splitapply(@min, chgtab(:,end), G);
chgtab_block_min_perzone = chgtab(arrayfun(@(x)find(chgtab(:,4)==x,1), zone), :);
chgtab_block_min_perzone(:,end) = minLoadperZone;
%max per zone
[G, zone] = findgroups(chgtab(:,4));
maxLoadperZone = splitapply(@max, chgtab(:,end), G);
chgtab_block_max = chgtab(arrayfun(@(x)find(chgtab(:,4)==x,1), zone), :);
chgtab_block_max(:,end) = maxLoadperZone;

%maxLoad = max(chgtab(:,7));
%chgtab_block_max = chgtab(1:6,:);
% chgtab_block_max(:,7) = maxLoad;

disp(chgtab_block_min)
disp(chgtab_block_min_perzone)
disp(chgtab_block_max)

labels_t = unique(chgtab_block_max(:, CT_LABEL));   % 1..number of branches
labels_k = unique(contab(:, CT_LABEL));   % list of contingency IDs
converged = 0;

for t = 1:numel(labels_t)
    mpc_t = apply_changes(labels_t(t), mpc, chgtab_block_max);  % apply that sample's loads

    for k = 1:numel(labels_k)
        mpc_t_k   = apply_changes(labels_k(k), mpc_t, contab);

        results_t = runpf(mpc_t_k, mpopt);
        if results_t.success == 1
              % converged
             % ... collect results ...
              converged = converged + 1;
        else
            risk(k) = 1;
            % did not converge
            % warning('Power flow did not converge');
        end 
    end
end
fprintf("%d / %d converged\n", converged, numel(labels_k));

f = mpc.branch(:, F_BUS);
t = mpc.branch(:, T_BUS);
G = graph(f, t);

figure;
h = plot(G, ...
    'Layout', 'force', ...
    'NodeColor', 'k', ...
    'MarkerSize', 3, ...
    'EdgeAlpha', 0.8);

title('ACTIVSg200 Network — N-1 Critical Lines Highlighted Maximal Load Per Zone');

% Color edges by N-1 risk
colormap(jet);
h.EdgeCData = risk;

colorbar;
ylabel(colorbar, 'N-1 Failure Risk');

% Make critical lines thicker
h.LineWidth = 0.5 + 4 * risk;