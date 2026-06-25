function result = lengths()
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
% contab = contab_ACTIVSg200;             % load the contingency table

result.kvs = mpc.bus(mpc.branch(:, F_BUS));
result.lens = result.kvs .* hypot(mpc.branch(:, BR_R), mpc.branch(:, BR_X));