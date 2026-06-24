import matpower as mp
import numpy as np

print("Instance launch...")
m = mp.start_instance(path_matpower="matpower8.1")
print("Instance online")


# Simple example of interaction with MATLAB code inside python
# Ineffective, invocation inside nested loops is 3x slower
# than the single call to function in MATLAB
def calc_LOLE_MC(num, seed):
    """Compute LOLE estimator through the Monte-Carlo simulation."""

    # Set options: silence matpower output
    mpopt = m.mpoption('verbose', 0, 'out.all', 0)

    # Define the base case
    m.define_constants()
    mpc = m.loadcase("case_ACTIVSg200")  # load the MATPOWER case
    # translate zones into areas
    mpc.bus[:, int(m.pull("BUS_AREA")) - 1] = mpc.bus[:, int(m.pull("ZONE")) - 1]

    # Load load scenarios
    scenarios = m.scenarios_ACTIVSg200()  # a chgtab matrix
    contab = m.contab_ACTIVSg200()        # load the contingency table
    # list of hours
    sc_labels = np.unique(scenarios[:, int(m.pull("CT_LABEL")) - 1])

    # list of contingency IDs
    ct_labels = np.unique(contab[:, int(m.pull("CT_LABEL")) - 1])

    # use seed to set RNG state, generate a sample of indices
    np.random.seed(seed)
    subsample = np.random.randint(0, sc_labels.shape[0], num)

    ct_total = ct_labels.shape[0]
    result = np.zeros((ct_total, num))

    for j in range(num):
        # apply new loads per zones
        mpc_t = m.apply_changes(sc_labels[subsample[j]], mpc, scenarios)

        for k in range(ct_total):
            mpc_tk = m.apply_changes(ct_labels[k], mpc_t, contab)
            results_tk = m.runpf(mpc_tk, mpopt)
            result[k, j] = results_tk.success == 1

    return result


def timeit(func):
    import time as t
    t1 = t.perf_counter_ns()
    result = func()
    t2 = t.perf_counter_ns()
    return result, (t2 - t1) * 1e-9


print("Evaluation (Py)...")
result, time = timeit(lambda: calc_LOLE_MC(1, 42))
print(f"Took {time:.1f} second(s)")

# print("Evaluation (PyOct)...")
# _, time = timeit(lambda: m.feval("calc_LOLE_MC_200.m", 1, 42))
# print(f"Took {time:.1f} second(s)")
