#!/bin/bash

set -e
set -x

CURDATE=$(date +"%Y-%m-%dT%H:%M:%S%z")
TIMEOUT=5h

JOB_LOG_DIR="$LCWS/results/jobs/"
mkdir -p "$JOB_LOG_DIR"
JOB_LOG="$JOB_LOG_DIR/openmp-offload-$CURDATE"
flux submit -N 1 -x -t "$TIMEOUT" --output="$JOB_LOG" ./flux_job.sh
