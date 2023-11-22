#!/bin/bash

set -e
set -x

module load rocm
module load ninja

llvm-build-corona.sh --release
source "$HOME/bin/llvm-enable-corona.sh" --release


CURDATE=$(date +"%Y-%m-%dT%H:%M:%S%z")
HOST=$(hostname)

FACTORS="1 2 3 4 5 6 7 8 9 10"
DYN_CONV="0 1"
NRUNS="3"

for dc in $DYN_CONV; do
    for i in $FACTORS; do
        JOB_NAME="$dc-$i"
        OMP_PROFILE_DIR="$LCWS/results/openmc-offload/$CURDATE/omp-profile-$JOB_NAME-dir"
        mkdir -p "$OMP_PROFILE_DIR"

        export UNROLL_AND_INTERLEAVE_FACTOR="$i"
        export UNROLL_AND_INTERLEAVE_DYNAMIC_CONVERGENCE="$dc"

        # Sometimes ccache from different nodes interact badly and things fail
        #export CCACHE_DISABLE=1

        RUN_INFO="$OMP_PROFILE_DIR/run_info"

        echo "Factor is $i" 2>&1 | tee -a "$RUN_INFO"
        echo "Dynamic convergence is $dc" 2>&1 | tee -a "$RUN_INFO"
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

CURDATE="$(date +"%Y-%m-%dT%H:%M:%S%z")"
echo END "$CURDATE"
