clc;
clear all;
close all;

yearly_mls_statistical = load("yearly_mls_weighted.mat").yearly_mls;
yearly_mls_statistical = 3 * yearly_mls_statistical / 1e3; % Weight by euros

%% Histogram of expected yearly MLS by line
f = figure;
set(gcf, 'Color', 'w')
histogram(yearly_mls_statistical(yearly_mls_statistical~=0), 10);
xlabel("Expected Cost, €");
ylabel("Frequency");
exportgraphics(f, "Histogram_E_MLS_by_line.pdf");
