function result = lengths(mpc)
define_constants;

branch_kv = mpc.bus(mpc.branch(:, F_BUS), BASE_KV);
result = (branch_kv.^2) .* hypot(mpc.branch(:,BR_R), mpc.branch(:, BR_X));
