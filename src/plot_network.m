%% Define the base case
define_constants;

mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
contab = contab_ACTIVSg200;             % load the contingency table

%graph of the busses
G = graph(mpc.branch(:, 1), mpc.branch(:, 2));
[x y] = graph_get_coords(G);
[G x y] = graph_min_length(G, x, y, 0.5);

f = figure;
title('Network Graph');
p = plot(G, ...
    'XData', x, ...
    'YData', y);
p.MarkerSize = 5; % Increase node size
p.LineWidth = 1.25; % Thicken edges

provide_network_design;
%check the overlapping nodes
%rows195 = mpc.branch(:,1) == 195 | mpc.branch(:,2) == 195;
%branch195 = mpc.branch(rows195,:);
%pairs195 = mpc.branch(rows195, 1:2);
%disp(pairs195)

% Customize node colors based on bus types

PQColor    = [230, 159, 0]/255;   % Orange
PVColor    = [213, 94, 0]/255;    % Vermilion
SlackColor = [0, 158, 115]/255;   % Bluish green

nodeColors = mpc.bus(:, BUS_TYPE);

p.NodeColor = ((nodeColors == 1) * PQColor ...
       + (nodeColors == 2) * PVColor ...
       + (nodeColors == 3) * SlackColor);


hold on
h1 = plot(nan,nan,'o','MarkerFaceColor',PQColor,'MarkerEdgeColor',PQColor,'MarkerSize',8);
h2 = plot(nan,nan,'o','MarkerFaceColor',PVColor,'MarkerEdgeColor',PVColor,'MarkerSize',8);
h3 = plot(nan,nan,'o','MarkerFaceColor',SlackColor,'MarkerEdgeColor',SlackColor,'MarkerSize',8);

% hold off
lgd = legend([h1 h2 h3], {'Consumer Bus','Generator Bus','Reference Bus'}, ...
       'Location','best');
lgd.FontSize = 12;

exportgraphics(f, "Network.pdf");

% Calculate the net demand/supply per node
%netDemandReal = mpc.branch(:, Pf) - mpc.bus(:, Pt); % Calculate net demand
%netDemandComplex = mpc.branch(:, Qf) - mpc.branch(:, Qt)
%fprintf('Net Demand/Supply (Real): %.2f\n', netDemandReal);
%fprintf('Net Demand/Supply (Complex): %.2f\n', netDemandComplex);