### Post analysis mode

1. The simulation is propagated using GROMACS without PLUMED
2. The progress coordinate is calculated by post-analysis of the trajectory using ```plumed driver```.

Usually applicable for large systems (>100,000 atoms) and using GPU hardware for MD simulation.
