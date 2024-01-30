#!/bin/bash

set -e
set -x

module load rocm
llvm-build-tioga.sh --release
. enable.sh /p/lustre1/ivanov2/opt/llvm-release/install/


CURDATE=$(date +"%Y-%m-%dT%H:%M:%S%z")

NRUNS="3"

DISTRIBUTE_FACTORS="1 2 4"
FOR_FACTORS="1 2 4"
DYN_CONV="0 1"
TIMEOUT=8h

for d in $DISTRIBUTE_FACTORS; do
for f in $FOR_FACTORS; do
for dc in $DYN_CONV; do
    JOB_NAME="$d-$f-$dc"
    OMP_PROFILE_DIR="$LCWS/results/openmc-offload/$CURDATE/omp-profile-$JOB_NAME-dir"
    mkdir -p "$OMP_PROFILE_DIR"

    export OMPX_COARSEN_DISTRIBUTE_OVERRIDE="$d"
    export OMPX_COARSEN_FOR_OVERRIDE="$f"
    export UNROLL_AND_INTERLEAVE_DYNAMIC_CONVERGENCE="$dc"

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
        LIBOMPTARGET_PROFILE_GRANULARITY=1 LIBOMPTARGET_PROFILE="$LIBOMPTARGET_PROFILE_DIR/openmp.profile.out.$run" ./build_openmc.sh performance 2>&1 | tee -a "$RUN_INFO"
    done
done
done
done

CURDATE="$(date +"%Y-%m-%dT%H:%M:%S%z")"
echo END "$CURDATE"
