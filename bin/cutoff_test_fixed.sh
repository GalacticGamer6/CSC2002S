#!/usr/bin/env bash

set -u

RESULTS_DIR="results/cutoff"
mkdir -p "$RESULTS_DIR"

REPETITIONS=7
WARMUPS=2

GRID_ROWS=500
GRID_COLS=500

SEED=17
MODE=wildfire
LANDSCAPE=mixed
MAX_STEPS=50000
TOLERANCE=0.05

CUTOFFS=(500 1000 2500 5000 10000 20000 40000 80000)

extract_time() {
    grep "^Core simulation time" "$1" |
        head -n 1 |
        cut -d':' -f2- |
        sed 's/ms//' |
        xargs |
        tr ',' '.'
}

extract_steps() {
    grep "^Timesteps completed" "$1" |
        head -n 1 |
        cut -d':' -f2- |
        xargs
}

run_serial() {
    java -cp bin FirelineSerial \
        "$GRID_ROWS" "$GRID_COLS" "$SEED" "$MODE" "$1" \
        "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
        > "$2" 2>&1
}

run_parallel() {
    java -Dfireline.cutoff="$1" -cp bin FirelineParallel \
        "$GRID_ROWS" "$GRID_COLS" "$SEED" "$MODE" "$3" \
        "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" \
        > "$2" 2>&1
}

echo "============================================================"
echo "SEQUENTIAL CUTOFF EXPERIMENT"
echo "============================================================"
echo "Case: ${GRID_ROWS}x${GRID_COLS}, seed=$SEED, $MODE, $LANDSCAPE"
echo "Warm-ups: $WARMUPS"
echo "Measured repetitions: $REPETITIONS"
echo

echo "Warming up serial..."

for ((i=1; i<=WARMUPS; i++)); do
    run_serial \
        "$RESULTS_DIR/warmup_serial_$i" \
        "$RESULTS_DIR/warmup_serial_$i.txt"
done

echo
echo "SERIAL BASELINE"

serial_times=()
serial_steps=""

for ((i=1; i<=REPETITIONS; i++)); do
    run_serial \
        "$RESULTS_DIR/serial_$i" \
        "$RESULTS_DIR/serial_$i.txt"

    t=$(extract_time "$RESULTS_DIR/serial_$i.txt")
    s=$(extract_steps "$RESULTS_DIR/serial_$i.txt")

    serial_times+=("$t")
    serial_steps="$s"

    echo "  Run $i: $t ms"
done

serial_sorted=($(printf '%s\n' "${serial_times[@]}" | sort -n))
serial_median="${serial_sorted[$((REPETITIONS / 2))]}"

echo
echo "  Serial median: $serial_median ms"
echo "  Timesteps: $serial_steps"

echo
echo "Warming up parallel..."

for cutoff in "${CUTOFFS[@]}"; do

    for ((i=1; i<=WARMUPS; i++)); do
        run_parallel \
            "$cutoff" \
            "$RESULTS_DIR/warmup_parallel_${cutoff}_$i.txt" \
            "$RESULTS_DIR/warmup_parallel_${cutoff}_$i"
    done

done

csv="$RESULTS_DIR/cutoff_results.csv"

echo "cutoff,repetition,time_ms,timesteps,speedup_vs_serial_median" > "$csv"

echo
echo "CUTOFF RESULTS"

for cutoff in "${CUTOFFS[@]}"; do

    echo
    echo "------------------------------------------------------------"
    echo "Cutoff: $cutoff"
    echo "------------------------------------------------------------"

    times=()
    steps_for_cutoff=""

    for ((i=1; i<=REPETITIONS; i++)); do

        output_file="$RESULTS_DIR/parallel_${cutoff}_$i.txt"
        prefix="$RESULTS_DIR/parallel_${cutoff}_$i"

        run_parallel "$cutoff" "$output_file" "$prefix"

        t=$(extract_time "$output_file")
        s=$(extract_steps "$output_file")

        times+=("$t")
        steps_for_cutoff="$s"

        speedup=$(awk \
            -v a="$serial_median" \
            -v b="$t" \
            'BEGIN { printf "%.4f", a / b }')

        echo "  Run $i:"
        echo "    Parallel: $t ms"
        echo "    Serial median: $serial_median ms"
        echo "    Speedup: ${speedup}x"
        echo "    Timesteps: $s"

        echo "$cutoff,$i,$t,$s,$speedup" >> "$csv"

    done

    sorted=($(printf '%s\n' "${times[@]}" | sort -n))
    median="${sorted[$((REPETITIONS / 2))]}"

    best_speedup=$(awk \
        -v a="$serial_median" \
        -v b="$median" \
        'BEGIN { printf "%.4f", a / b }')

    echo
    echo "  Cutoff summary:"
    echo "    Median parallel time: $median ms"
    echo "    Timesteps: $steps_for_cutoff"
    echo "    Speedup: ${best_speedup}x"

done

echo
echo "============================================================"
echo "CUTOFF EXPERIMENT COMPLETE"
echo "============================================================"
echo "Raw results: $csv"
