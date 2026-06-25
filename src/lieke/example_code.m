%% Define the base case
define_constants;

mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
contab = contab_ACTIVSg200;             % load the contingency table

% set options: silence matpower output
mpopt = mpoption('verbose', 0, 'out.all', 0); % set verbose to 1 to obtain output for all cases

%% N-1 analysis of the base case
% apply the contingencies one by one
% labels = unique(contab(:, CT_LABEL));   % list of contingency IDs
% converged = 0;
% for k = 1:numel(labels)
%     mpc_k   = apply_changes(labels(k), mpc, contab);
% 
%     % run power flow computation
%     results_k = runpf(mpc_k, mpopt);             
%     if results_k.success == 1
%         % converged
%         % ... collect results ...
%         converged = converged + 1;
%     else
%         % did not converge
%         % warning('Power flow did not converge');
%     end
% end
% fprintf("%d / %d converged\n", converged, numel(labels));

%% Time series data
% sc = scenarios_ACTIVSg200;    % capture the returned data
% sc_PD = sc(:, Pd);
% sc_QD = sc(:, Qd);

%for t = 1:8784
 %   mpc_t = mpc;
%    mpc_t.bus(:, PD) = sc_PD(:, t);   % hourly active load from the scenarios data
%    mpc_t.bus(:, QD) = sc_QD(:, t);   % if reactive is provided
%     
%    % run power flow computation
%    results_t = rundcpf(mpc_t);
%    % ... collect results ...
% end

% scenarios = scenarios_ACTIVSg200;          % a chgtab matrix, NOT a profile struct

% each distinct label = one load scenario / time sample%
% labels = unique(scenarios(:, CT_LABEL));
% converged = 0;
% 
% for t = 1:numel(labels)
%     mpc_t = apply_changes(labels(t), mpc, scenarios);  % apply that sample's loads
% 
%     results_t = runpf(mpc_t, mpopt);
%     if results_t.success == 1
%         % converged
%         % ... collect results ...
%         converged = converged + 1;
%     else
%         % did not converge
%         % warning('Power flow did not converge');
%     end
% 
% end
% fprintf("%d / %d converged\n", converged, numel(labels));

%graph of the busses
from = mpc.branch(:,1);   % from bus
to   = mpc.branch(:,2);   % to bus

G = graph(from, to);

figure;
title('Network Graph');
p = plot(G, 'Layout', 'force', 'NodeLabel', unique([from; to]));
p.MarkerSize = 5; % Increase node size
p.LineWidth = 1.5; % Thicken edges

%check the overlapping nodes
%rows195 = mpc.branch(:,1) == 195 | mpc.branch(:,2) == 195;
%branch195 = mpc.branch(rows195,:);
%pairs195 = mpc.branch(rows195, 1:2);
%disp(pairs195)

% Customize node colors based on bus types
nodeColors = mpc.bus(:, 2); 
p.NodeCData = nodeColors; 
nodeRGB = zeros(numnodes(G),3);

nodeRGB(nodeColors==1,:) = repmat([0 0 1], sum(nodeColors==1), 1);
nodeRGB(nodeColors==2,:) = repmat([0 1 0], sum(nodeColors==2), 1);
nodeRGB(nodeColors==3,:) = repmat([1 0 0], sum(nodeColors==3), 1);

% Calculate the net demand/supply per node
netDemandReal = mpc.branch(:, Pf) - mpc.bus(:, Pt); % Calculate net demand
netDemandComplex = mpc.branch(:, Qf) - mpc.branch(:, Qt)

fprintf('Net Demand/Supply (Real): %.2f\n', netDemandReal);
fprintf('Net Demand/Supply (Complex): %.2f\n', netDemandComplex);
