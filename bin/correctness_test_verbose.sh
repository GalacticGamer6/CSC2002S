#!/usr/bin/env bash

# CSC2002S PCP1 - Fireline correctness tests
#
# Run from src/ after compiling:
#   make
#
# This script compares serial and parallel on several deterministic cases.
# It prints the SERIAL and PARALLEL values side-by-side and compares all
# three generated PNGs byte-for-byte using SHA-256 hashes.

set -u

RESULTS_DIR="results/correctness"
CUTOFF=10000

mkdir -p "$RESULTS_DIR"

PASS_COUNT=0
FAIL_COUNT=0

get_value() {
    local label="$1"
    local file="$2"

    grep "^${label}" "$file" | head -n 1 | cut -d':' -f2- | xargs
}

compare_value() {
    local label="$1"
    local serial_value="$2"
    local parallel_value="$3"

    printf "  %-30s\n" "$label"
    printf "    Serial:   %s\n" "$serial_value"
    printf "    Parallel: %s\n" "$parallel_value"

    if [ "$serial_value" = "$parallel_value" ]; then
        echo "    Status:   MATCH"
        return 0
    fi

    echo "    Status:   DIFFER"
    return 1
}

run_case() {
    local case_name="$1"
    local rows="$2"
    local columns="$3"
    local seed="$4"
    local mode="$5"
    local landscape="$6"
    local max_steps="$7"
    local tolerance="$8"

    shift 8

    local serial_prefix="${RESULTS_DIR}/${case_name}_serial"
    local parallel_prefix="${RESULTS_DIR}/${case_name}_parallel"

    local serial_output="${RESULTS_DIR}/${case_name}_serial.txt"
    local parallel_output="${RESULTS_DIR}/${case_name}_parallel.txt"

    echo
    echo "============================================================"
    echo "CASE: $case_name"
    echo "Grid: ${rows}x${columns}"
    echo "Seed: $seed"
    echo "Mode: $mode"
    echo "Landscape: $landscape"
    echo "============================================================"

    local common_args=(
        "$rows"
        "$columns"
        "$seed"
        "$mode"
        ""
        "$max_steps"
        "$tolerance"
        "$landscape"
    )

    if [ "$#" -gt 0 ]; then
        common_args+=("$@")
    fi

    # --------------------------------------------------------
    # Serial
    # --------------------------------------------------------
    echo "Running serial..."

    local serial_args=("${common_args[@]}")
    serial_args[4]="$serial_prefix"

    java -cp bin FirelineSerial "${serial_args[@]}" \
        > "$serial_output" 2>&1

    if [ $? -ne 0 ]; then
        echo "FAIL: Serial program failed."
        cat "$serial_output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    # --------------------------------------------------------
    # Parallel
    # --------------------------------------------------------
    echo "Running parallel..."

    local parallel_args=("${common_args[@]}")
    parallel_args[4]="$parallel_prefix"

    java -Dfireline.cutoff="$CUTOFF" \
        -cp bin FirelineParallel "${parallel_args[@]}" \
        > "$parallel_output" 2>&1

    if [ $? -ne 0 ]; then
        echo "FAIL: Parallel program failed."
        cat "$parallel_output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    # --------------------------------------------------------
    # Compare simulation results
    # --------------------------------------------------------
    echo
    echo "Simulation result comparison:"

    local metrics_ok=true

    compare_value \
        "Timesteps" \
        "$(get_value 'Timesteps completed' "$serial_output")" \
        "$(get_value 'Timesteps completed' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Converged" \
        "$(get_value 'Converged' "$serial_output")" \
        "$(get_value 'Converged' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Final burning cells" \
        "$(get_value 'Final burning cells' "$serial_output")" \
        "$(get_value 'Final burning cells' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Cells burned" \
        "$(get_value 'Cells burned' "$serial_output")" \
        "$(get_value 'Cells burned' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Maximum peak temperature" \
        "$(get_value 'Maximum peak temperature' "$serial_output")" \
        "$(get_value 'Maximum peak temperature' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Final maximum change" \
        "$(get_value 'Maximum change in final timestep' "$serial_output")" \
        "$(get_value 'Maximum change in final timestep' "$parallel_output")" \
        || metrics_ok=false

    compare_value \
        "Initial source" \
        "$(get_value 'Initial source' "$serial_output")" \
        "$(get_value 'Initial source' "$parallel_output")" \
        || metrics_ok=false

    # --------------------------------------------------------
    # Compare generated images byte-for-byte
    # --------------------------------------------------------
    echo
    echo "Image comparison:"

    local images_ok=true

    for suffix in "_terrain.png" "_peak.png" "_final.png"; do
        local serial_image="${serial_prefix}${suffix}"
        local parallel_image="${parallel_prefix}${suffix}"

        echo
        echo "  ${suffix}"

        if [ ! -f "$serial_image" ]; then
            echo "    Serial image:   MISSING"
            images_ok=false
            continue
        fi

        if [ ! -f "$parallel_image" ]; then
            echo "    Parallel image: MISSING"
            images_ok=false
            continue
        fi

        local serial_hash
        local parallel_hash

        serial_hash=$(sha256sum "$serial_image" | cut -d' ' -f1)
        parallel_hash=$(sha256sum "$parallel_image" | cut -d' ' -f1)

        echo "    Serial SHA-256:   $serial_hash"
        echo "    Parallel SHA-256: $parallel_hash"

        if [ "$serial_hash" = "$parallel_hash" ]; then
            echo "    Status:           IDENTICAL"
        else
            echo "    Status:           DIFFERENT"
            images_ok=false
        fi
    done

    # --------------------------------------------------------
    # Overall result
    # --------------------------------------------------------
    echo

    if [ "$metrics_ok" = true ] && [ "$images_ok" = true ]; then
        echo "RESULT: PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "RESULT: FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ============================================================
# CORRECTNESS CASES
# ============================================================

run_case \
    "C1_100x100_seed17_wildfire_mixed" \
    100 100 17 wildfire mixed 50000 0.05

run_case \
    "C2_300x300_seed42_wildfire_mixed" \
    300 300 42 wildfire mixed 50000 0.05

run_case \
    "C3_500x500_seed17_wildfire_mixed" \
    500 500 17 wildfire mixed 50000 0.05

run_case \
    "C4_500x500_seed17_diffusion_mixed" \
    500 500 17 diffusion mixed 50000 0.05

run_case \
    "C5_1000x1000_seed17_wildfire_grass" \
    1000 1000 17 wildfire grass 50000 0.05 \
    20 20 9

# ============================================================
# SUMMARY
# ============================================================

echo
echo "============================================================"
echo "CORRECTNESS SUMMARY"
echo "============================================================"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo
    echo "ALL CORRECTNESS TESTS PASSED."
    exit 0
else
    echo
    echo "SOME CORRECTNESS TESTS FAILED."
    exit 1
fi
