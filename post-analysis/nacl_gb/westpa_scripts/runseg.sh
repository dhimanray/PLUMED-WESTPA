#!/bin/bash
#
# runseg.sh
#
# WESTPA runs this script for each trajectory segment. WESTPA supplies
# environment variables that are unique to each segment, such as:
#
#   WEST_CURRENT_SEG_DATA_REF: A path to where the current trajectory segment's
#       data will be stored. This will become "WEST_PARENT_DATA_REF" for any
#       child segments that spawn from this segment
#   WEST_PARENT_DATA_REF: A path to a file or directory containing data for the
#       parent segment.
#   WEST_CURRENT_SEG_INITPOINT_TYPE: Specifies whether this segment is starting
#       anew, or if this segment continues from where another segment left off.
#   WEST_RAND16: A random integer
#
# This script has the following three jobs:
#  1. Create a directory for the current trajectory segment, and set up the
#     directory for running gmx mdrun
#  2. Run the dynamics
#  3. Calculate the progress coordinates and return data to WESTPA



# If we are running in debug mode, then output a lot of extra information.
if [ -n "$SEG_DEBUG" ] ; then
    set -x
    env | sort
fi

######################## Set up for running the dynamics #######################

# Set up the directory where data for this segment will be stored.
cd $WEST_SIM_ROOT
mkdir -pv $WEST_CURRENT_SEG_DATA_REF
cd $WEST_CURRENT_SEG_DATA_REF

# Make a symbolic link to the topology file. This is not unique to each segment.
ln -sv $WEST_SIM_ROOT/gromacs_config/nacl.top .

# Either continue an existing tractory, or start a new trajectory. In the 
# latter case, we need to do a couple things differently, such as generating
# velocities.
#
# First, take care of the case that this segment is a continuation of another
# segment.  WESTPA provides the environment variable 
# $WEST_CURRENT_SEG_INITPOINT_TYPE, and we check its value.
if [ "$WEST_CURRENT_SEG_INITPOINT_TYPE" = "SEG_INITPOINT_CONTINUES" ]; then
  # The weighted ensemble algorithm requires that dynamics are stochastic.
  # We'll use the "sed" command to replace the string "RAND" with a randomly
  # generated seed.
  sed "s/RAND/$WEST_RAND16/g" \
    $WEST_SIM_ROOT/gromacs_config/md-continue.mdp > md.mdp

  # This trajectory segment will start off where its parent segment left off.
  # The "ln" command makes symbolic links to the parent segment's edr, gro, and 
  # and trr files. This is preferable to copying the files, since it doesn't
  # require writing all the data again.
  ln -sv $WEST_PARENT_DATA_REF/seg.edr ./parent.edr
  ln -sv $WEST_PARENT_DATA_REF/seg.gro ./parent.gro
  ln -sv $WEST_PARENT_DATA_REF/seg.trr ./parent.trr
  ln -sv $WEST_SIM_ROOT/gromacs_config/plumed.dat ./plumed.dat

  # Run the GROMACS preprocessor 
  $GMX grompp -f md.mdp -c parent.gro -e parent.edr -p nacl.top \
    -t parent.trr -o seg.tpr -po md_out.mdp

# Now take care of the case that the trajectory is starting anew.
elif [ "$WEST_CURRENT_SEG_INITPOINT_TYPE" = "SEG_INITPOINT_NEWTRAJ" ]; then
  # Again, we'll use the "sed" command to replace the string "RAND" with a 
  # randomly generated seed.
  sed "s/RAND/$WEST_RAND16/g" \
    $WEST_SIM_ROOT/gromacs_config/md-genvel.mdp > md.mdp

  # For a new segment, we only need to make a symbolic link to the .gro file.
  ln -sv $WEST_PARENT_DATA_REF ./parent.gro
  ln -sv $WEST_SIM_ROOT/gromacs_config/plumed.dat ./plumed.dat

  # Run the GROMACS preprocessor
  $GMX grompp -f md.mdp -c parent.gro -p nacl.top \
    -o seg.tpr -po md_out.mdp
fi


############################## Run the dynamics ################################
# Propagate the segment using gmx mdrun without plumed
$GMX mdrun -s seg.tpr -o seg.trr -c  seg.gro -e seg.edr \
  -cpo seg.cpt -g seg.log 

########################## Calculate and return data ###########################

# post analysis of trajectory with plumed
plumed driver --plumed plumed.dat --mf_trr seg.trr
# Calculate the progress coordinate
python $WEST_SIM_ROOT/westpa_scripts/progress_coord.py > $WEST_PCOORD_RETURN

# Output coordinates.  To do this, we'll use trjconv to make a PDB file. Then
# we can parse the PDB file using grep and awk, only taking the x,y,z values
# for the coordinates.
echo -e "0 \n" | $GMX trjconv -f seg.trr -s seg.tpr -o seg.pdb
cat seg.pdb | grep 'ATOM' | awk '{print $6, $7, $8}' > $WEST_COORD_RETURN

# Output log
if [ ${WEST_LOG_RETURN} ]; then
    cat $WEST_CURRENT_SEG_DATA_REF/seg.log \
      | awk '/Started mdrun/ {p=1}; p; /A V E R A G E S/ {p=0}' \
      > $WEST_LOG_RETURN
fi

# Clean up all the files that we don't need to save.
rm -f md.mdp md_out.mdp nacl.top parent.gro parent.trr seg.cpt \
  seg.pdb seg.tpr
