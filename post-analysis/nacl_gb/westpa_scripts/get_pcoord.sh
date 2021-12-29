#!/bin/bash
#
# get_pcoord.sh
#
# This script is run when calculating initial progress coordinates for new 
# initial states (istates).  This script is NOT run for calculating the progress
# coordinates of most trajectory segments; that is instead the job of runseg.sh.

# If we are debugging, output a lot of extra information.
if [ -n "$SEG_DEBUG" ] ; then
    set -x
    env | sort
fi

cd $WEST_SIM_ROOT/bstates || exit 1 
plumed driver --plumed $WEST_SIM_ROOT/gromacs_config/plumed.dat --mf_pdb nacl.pdb
python init_progress_coord.py > $WEST_PCOORD_RETURN


