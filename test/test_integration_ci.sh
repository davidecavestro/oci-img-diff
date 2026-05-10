#!/usr/bin/env bash

# Integration tests for GitHub Actions CI environment
# More robust handling of CI-specific issues

test_integration_ci_basic_functionality() {
  TEMP_DIR=$(mktemp -d)
  
  echo "=== Testing basic functionality ==="
  echo "TEMP_DIR: $TEMP_DIR"
  
  # Test with absolute path to main.sh
  MAIN_SCRIPT="$(dirname "$0")/../main.sh"
  echo "MAIN_SCRIPT: $MAIN_SCRIPT"
  
  if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "FAIL: main.sh not found at $MAIN_SCRIPT"
    return 1
  fi
  
  # Test basic functionality
  output=$("$MAIN_SCRIPT" \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc \
    --output-dir "$TEMP_DIR" 2>&1)
  status=$?
  
  echo "Exit status: $status"
  echo "Output length: ${#output}"
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Basic functionality works"
  else
    echo "FAIL: Basic functionality failed with status $status"
    echo "Last 50 lines of output:"
    echo "$output" | tail -50
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.txt" ]; then
    echo "PASS: Report file created"
  else
    echo "FAIL: Report file not created"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_integration_ci_with_inflation() {
  TEMP_DIR=$(mktemp -d)
  
  echo "=== Testing archive inflation ==="
  
  # Test with inflation
  MAIN_SCRIPT="$(dirname "$0")/../main.sh"
  output=$("$MAIN_SCRIPT" \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /usr/lib \
    --output-dir "$TEMP_DIR" \
    --inflate 2>&1)
  status=$?
  
  echo "Exit status: $status"
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Archive inflation works"
  else
    echo "FAIL: Archive inflation failed with status $status"
    echo "Last 50 lines of output:"
    echo "$output" | tail -50
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.txt" ]; then
    echo "PASS: Report file created with inflation"
  else
    echo "FAIL: Report file not created with inflation"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}
