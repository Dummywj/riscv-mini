#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/sim/build"
LOG_DIR="$BUILD_DIR/logs"
TESTLIST="$ROOT_DIR/dv/tests/testlist.txt"
SIMV="$BUILD_DIR/rv32i_tb.vvp"

mkdir -p "$LOG_DIR"

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
  echo "BLOCKED: iverilog and vvp are required for this directed regression"
  exit 127
fi

iverilog -g2012 \
  -I "$ROOT_DIR/rtl/include" \
  -s rv32i_tb \
  -o "$SIMV" \
  "$ROOT_DIR/rtl/src/rv32i_single_cycle_cpu.sv" \
  "$ROOT_DIR/dv/assertions/rv32i_single_cycle_cpu_assertions.sv" \
  "$ROOT_DIR/dv/tb/rv32i_tb.sv"

failures=0
while IFS= read -r test_name; do
  if [[ -z "$test_name" || "$test_name" =~ ^# ]]; then
    continue
  fi
  log_file="$LOG_DIR/${test_name}.log"
  echo "Running $test_name"
  if vvp "$SIMV" +TEST="$test_name" > "$log_file" 2>&1; then
    echo "PASS $test_name"
  else
    echo "FAIL $test_name (see $log_file)"
    failures=$((failures + 1))
  fi
done < "$TESTLIST"

if [ "$failures" -ne 0 ]; then
  echo "REGRESSION FAIL: $failures test(s) failed"
  exit 1
fi

echo "REGRESSION PASS"
