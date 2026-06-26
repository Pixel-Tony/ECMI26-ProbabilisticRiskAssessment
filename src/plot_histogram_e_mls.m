clc;
clear all;
close all;

yearly_mls_statistical = load("yearly_mls_statistical.mat").yearly_mls_statistical;

%% Histogram of expected yearly MLS by line
f = figure;
set(gcf, 'Color', 'w')
histogram(yearly_mls_statistical(yearly_mls_statistical~=0), 10);
xlabel("Expected MLS, MWh");
ylabel("Frequency");
exportgraphics(f, "Histogram_E_MLS_by_line.pdf");
