#!/usr/bin/env bash
set -u

RESULTS_DIR="results/benchmark"
mkdir -p "$RESULTS_DIR"

REPETITIONS=7
WARMUPS=2
CUTOFF=10000

SEED=17
MODE=wildfire
LANDSCAPE=mixed
MAX_STEPS=50000
TOLERANCE=0.05

SIZES=(100 200 300 500 750 1000 1500)

extract_time() {
    grep "^Core simulation time" "$1" | head -n 1 |
        cut -d':' -f2- | sed 's/ms//' | xargs | tr ',' '.'
}

extract_steps() {
    grep "^Timesteps completed" "$1" | head -n 1 |
        cut -d':' -f2- | xargs
}

run_serial() {
    java -cp bin FirelineSerial "$1" "$1" "$SEED" "$MODE" "$2" \
        "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" > "$3" 2>&1
}

run_parallel() {
    java -Dfireline.cutoff="$CUTOFF" -cp bin FirelineParallel \
        "$1" "$1" "$SEED" "$MODE" "$2" \
        "$MAX_STEPS" "$TOLERANCE" "$LANDSCAPE" > "$3" 2>&1
}

echo "============================================================"
echo "MAIN SERIAL VS PARALLEL BENCHMARK"
echo "============================================================"
echo "Seed: $SEED"
echo "Mode: $MODE"
echo "Landscape: $LANDSCAPE"
echo "Cutoff: $CUTOFF"
echo "Warm-ups: $WARMUPS"
echo "Measured repetitions: $REPETITIONS"
echo

csv="$RESULTS_DIR/speedup_results.csv"
echo "grid,serial_median_ms,parallel_median_ms,speedup,serial_timesteps,parallel_timesteps" > "$csv"

for size in "${SIZES[@]}"; do
    echo
    echo "============================================================"
    echo "GRID: ${size}x${size}"
    echo "============================================================"

    echo "Warming up..."
    for ((i=1; i<=WARMUPS; i++)); do
        run_serial "$size" \
            "$RESULTS_DIR/warmup_serial_${size}_$i" \
            "$RESULTS_DIR/warmup_serial_${size}_$i.txt"

        run_parallel "$size" \
            "$RESULTS_DIR/warmup_parallel_${size}_$i" \
            "$RESULTS_DIR/warmup_parallel_${size}_$i.txt"
    done

    echo
    echo "SERIAL"
    serial_times=()
    serial_steps=""

    for ((i=1; i<=REPETITIONS; i++)); do
        output_file="$RESULTS_DIR/serial_${size}_$i.txt"
        prefix="$RESULTS_DIR/serial_${size}_$i"

        run_serial "$size" "$prefix" "$output_file"

        t=$(extract_time "$output_file")
        s=$(extract_steps "$output_file")

        serial_times+=("$t")
        serial_steps="$s"

        echo "  Run $i: $t ms"
    done

    serial_sorted=($(printf '%s\n' "${serial_times[@]}" | sort -n))
    serial_median="${serial_sorted[$((REPETITIONS / 2))]}"

    echo "  Serial median: $serial_median ms"
    echo "  Timesteps: $serial_steps"

    echo
    echo "PARALLEL"
    parallel_times=()
    parallel_steps=""

    for ((i=1; i<=REPETITIONS; i++)); do
        output_file="$RESULTS_DIR/parallel_${size}_$i.txt"
        prefix="$RESULTS_DIR/parallel_${size}_$i"

        run_parallel "$size" "$prefix" "$output_file"

        t=$(extract_time "$output_file")
        s=$(extract_steps "$output_file")

        parallel_times+=("$t")
        parallel_steps="$s"

        echo "  Run $i: $t ms"
    done

    parallel_sorted=($(printf '%s\n' "${parallel_times[@]}" | sort -n))
    parallel_median="${parallel_sorted[$((REPETITIONS / 2))]}"

    speedup=$(awk -v a="$serial_median" -v b="$parallel_median" 'BEGIN{printf "%.4f",a/b}')

    echo
    echo "COMPARISON"
    echo "  Serial median:   $serial_median ms"
    echo "  Parallel median: $parallel_median ms"
    echo "  Speedup:         ${speedup}x"
    echo "  Serial steps:    $serial_steps"
    echo "  Parallel steps:  $parallel_steps"

    echo "$size,$serial_median,$parallel_median,$speedup,$serial_steps,$parallel_steps" >> "$csv"
done

echo
echo "============================================================"
echo "BENCHMARK COMPLETE"
echo "============================================================"
echo "Results: $csv"
