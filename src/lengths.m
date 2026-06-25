function result = lengths()
define_constants;
mpc = loadcase("case_ACTIVSg200");      % load the MATPOWER case
mpc.bus(:, BUS_AREA) = mpc.bus(:, ZONE);% translate zones into areas
% contab = contab_ACTIVSg200;             % load the contingency table

result.fbus = mpc.bus(mpc.branch(:, F_BUS), 1);
result.kvs = mpc.bus(mpc.branch(:, F_BUS), BASE_KV);
result.lens = result.kvs .* hypot(mpc.branch(:, BR_R), mpc.branch(:, BR_X));