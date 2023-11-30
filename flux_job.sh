#!/bin/bash

set -e
set -x

module load rocm
module load ninja

llvm-build-corona.sh --release
source "$HOME/bin/llvm-enable-corona.sh" --release


CURDATE=$(date +"%Y-%m-%dT%H:%M:%S%z")

#FACTORS="1 2 3 4 5 6 7 8 9 10"
#DYN_CONV="0 1"
FACTORS="1 2"
DYN_CONV="0 1"
COAL_FRIENDLY="0 1"
IDC="0 1"

NRUNS="3"

for dc in $DYN_CONV; do
for i in $FACTORS; do
for cf in $COAL_FRIENDLY; do
for idc in $IDC; do
    JOB_NAME="$dc-$i-$cf-$idc"
    OMP_PROFILE_DIR="$LCWS/results/openmc-offload/$CURDATE/omp-profile-$JOB_NAME-dir"
    mkdir -p "$OMP_PROFILE_DIR"

    export OMP_OPT_COARSENING_FACTOR="$i"
    export OMP_OPT_COARSENING_DYNAMIC_CONVERGENCE="$dc"
    export OMP_OPT_COARSENING_COALESCING_FRIENDLY="$cf"
    export OMP_OPT_COARSENING_INCREASE_DISTRIBUTE_CHUNKING="$idc"

    # Sometimes ccache from different nodes interact badly and things fail
    #export CCACHE_DISABLE=1

    RUN_INFO="$OMP_PROFILE_DIR/run_info"

    echo "Factor is $i" 2>&1 | tee -a "$RUN_INFO"
    echo "Dynamic convergence is $dc" 2>&1 | tee -a "$RUN_INFO"
    echo "Coalescing frienly is $cf" 2>&1 | tee -a "$RUN_INFO"
    echo "Change distribute chunking is $idc" 2>&1 | tee -a "$RUN_INFO"
    echo "Openmc offload:" 2>&1 | tee -a "$RUN_INFO"
    git log -1 2>&1 | tee -a "$RUN_INFO"
    cd openmc
    echo "Openmc:" 2>&1 | tee -a "$RUN_INFO"
    git log -1 2>&1 | tee -a "$RUN_INFO"
    cd -
    echo "clang:" 2>&1 | tee -a "$RUN_INFO"
    clang --version 2>&1 | tee -a "$RUN_INFO"
    clang++ --version 2>&1 | tee -a "$RUN_INFO"

    echo Compiling... 2>&1 | tee -a "$RUN_INFO"
    ./build_openmc.sh compile 2>&1 | tee -a "$RUN_INFO"

    echo Validating... 2>&1 | tee -a "$RUN_INFO"
    ./build_openmc.sh validate 2>&1 | tee -a "$RUN_INFO"

    echo Running... 2>&1 | tee -a "$RUN_INFO"
    LIBOMPTARGET_PROFILE_DIR="$OMP_PROFILE_DIR/openmc/"
    mkdir -p "$LIBOMPTARGET_PROFILE_DIR"
    for run in $(seq "$NRUNS"); do
            LIBOMPTARGET_PROFILE="$LIBOMPTARGET_PROFILE_DIR/openmp.profile.out.$run" ./build_openmc.sh performance 2>&1 | tee -a "$RUN_INFO"
    done
done
done
done
done

CURDATE="$(date +"%Y-%m-%dT%H:%M:%S%z")"
echo END "$CURDATE"
