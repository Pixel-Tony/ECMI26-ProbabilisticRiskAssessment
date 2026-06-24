define_constants;
scenarios = scenarios_ACTIVSg200(); % a chgtab matrix

% labels = unique(scenarios(:, CT_LABEL));

WEEK_N = 5;
N_ZONES = 6;

% values = scenarios(scenarios(:, CT_ROW) == 5, end);

zoned_values = reshape(scenarios(:, end), N_ZONES, []);

size(zoned_values)

% values_weekly = reshape(zoned_values(1:end - 24*N_ZONES), [24*7*N_ZONES, 364 / 7]);
% values_avg_weekly  = mean(values_weekly, 2);

figure();
% p = plot(values(24*WEEK_N:24*WEEK_N + 168*2));
p = plot(zoned_values');
% p = plot(zoned_values');
% legend(p, "Power usage #%d")
pause
