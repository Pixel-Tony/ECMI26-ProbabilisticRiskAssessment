function islands(mpc, contab) % Find island busses, i.e. busses with only one connecting branch
    sum(abs(makeIncidence(mpc.bus, mpc.branch)), 1) == 1;
end