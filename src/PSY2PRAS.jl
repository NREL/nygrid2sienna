using PRASInterface

sys = System("nys2019.json")

sequential_monte_carlo = PRAS.SequentialMonteCarlo(samples=2, seed=1)
shortfalls, = PRAS.assess(sys, PSY.Area, sequential_monte_carlo, PRAS.Shortfall())


lole = PRAS.LOLE(shortfalls)
eue = PRAS.EUE(shortfalls)
