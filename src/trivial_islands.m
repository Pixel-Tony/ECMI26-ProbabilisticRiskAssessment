function trivial_islands(mpc, contab) % Find non-generator island busses
    b_i = islands(mpc, contab);
    setdiff(mpc.bus(b_i, CT_LABEL), mpc.gen(:, CT_LABEL));
end;