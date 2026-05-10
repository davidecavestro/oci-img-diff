#!/usr/bin/env bash

# Integration tests running directly in devcontainer
# This file tests the complete workflow without Docker

test_integration_basic_text_format_comparison() {
  TEMP_DIR=$(mktemp -d)
  
  # Run the script directly
  output=$(../main.sh \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc \
    --output-dir "$TEMP_DIR" 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Basic text format comparison works"
  else
    echo "FAIL: Basic text format comparison failed with status $status"
    echo "Output: $output"
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.txt" ]; then
    echo "PASS: Text report file created"
  else
    echo "FAIL: Text report file not created"
    echo "Files in output directory:"
    ls -la "$TEMP_DIR"
    return 1
  fi
  
  # Check that diff contains expected content
  if grep -q "alpine-release" "$TEMP_DIR/diff_report.txt"; then
    echo "PASS: Diff contains expected content"
  else
    echo "FAIL: Diff missing expected content"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_integration_archive_inflation_feature() {
  TEMP_DIR=$(mktemp -d)
  
  # Test with inflation enabled
  output=$(../main.sh \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /usr/lib \
    --output-dir "$TEMP_DIR" \
    --inflate 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Archive inflation feature works"
  else
    echo "FAIL: Archive inflation feature failed with status $status"
    echo "Output: $output"
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

test_integration_no_differences_found() {
  TEMP_DIR=$(mktemp -d)
  
  output=$(../main.sh \
    --left alpine:3.22.2 \
    --right alpine:3.22.2 \
    --format text \
    --output-dir "$TEMP_DIR" 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Same image comparison works"
  else
    echo "FAIL: Same image comparison failed with status $status"
    echo "Output: $output"
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.txt" ]; then
    echo "PASS: Report file created for same image"
  else
    echo "FAIL: Report file not created for same image"
    return 1
  fi
  
  # Should contain some output (even same images may show differences due to timestamps)
  size=$(wc -c < "$TEMP_DIR/diff_report.txt")
  if [ "$size" -gt 0 ]; then
    echo "PASS: Report has content for same image comparison"
  else
    echo "FAIL: Report is empty for same image comparison"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_integration_stdout_output() {
  output=$(../main.sh \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc \
    --stdout 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Stdout output works"
  else
    echo "FAIL: Stdout output failed with status $status"
    return 1
  fi
  
  # Check for any diff output, not just alpine-release
  if echo "$output" | grep -q "diff"; then
    echo "PASS: Stdout contains diff content"
  else
    echo "FAIL: Stdout missing diff content"
    return 1
  fi
}
