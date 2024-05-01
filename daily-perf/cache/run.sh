#!/usr/bin/env bash

set -x
set -eu

SYSTEMSLAB_URL="${SYSTEMSLAB_URL:-http://systemslab}"
SYSTEMSLAB=${SYSTEMSLAB:-systemslab}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Duration per experiment.
DURATION=3600

# Workspace config
NKEYS=10000
KLEN=10
VLEN=4000
RW_RATIO=1

# Client settings
CLIENT_THREADS=4
CLIENT_POOLSIZE=100
CLIENT_CONCURRENCY=1

cd "$SCRIPT_DIR"

$SYSTEMSLAB submit \
    --output-format short \
    --param "duration=$DURATION" \
    --param "nkeys=$NKEYS" \
    --param "klen=$KLEN" \
    --param "vlen=$VLEN" \
    --param "rw_ratio=$RW_RATIO" \
    --param "threads=$CLIENT_THREADS" \
    --param "poolsize=$CLIENT_POOLSIZE" \
    --param "concurrency=$CLIENT_CONCURRENCY" \
    bench.jsonnet
