#!/usr/bin/env bash

# Integration tests - Fixed version
# This file tests the complete workflow with Docker containers

test_integration_basic_text_format_comparison() {
  TEMP_DIR=$(mktemp -d)
  
  # Build test image first
  cd .. && docker build -t oci-img-diff-test . >/dev/null 2>&1
  cd test
  
  output=$(docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: Basic text format comparison works"
  else
    echo "FAIL: Basic text format comparison failed with status $status"
    echo "Output: $output"
    return 1
  fi
  
  # Wait a moment for file to be written
  sleep 2
  
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

test_integration_html_format_with_binary_files() {
  TEMP_DIR=$(mktemp -d)
  
  output=$(docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format html \
    --path /bin 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: HTML format with binary files works"
  else
    echo "FAIL: HTML format with binary files failed with status $status"
    echo "Output: $output"
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.html" ]; then
    echo "PASS: HTML report file created"
  else
    echo "FAIL: HTML report file not created"
    return 1
  fi
  
  # Check that HTML contains binary file differences
  if grep -q "Binary file (content differs)" "$TEMP_DIR/diff_report.html"; then
    echo "PASS: HTML contains binary file differences"
  else
    echo "FAIL: HTML missing binary file differences"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_integration_archive_inflation_feature() {
  TEMP_DIR=$(mktemp -d)
  
  # Test with inflation enabled
  output=$(docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /usr/lib \
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
  
  output=$(docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.22.2 \
    --format text 2>&1)
  status=$?
  
  if [ "$status" -eq 0 ]; then
    echo "PASS: No differences scenario works"
  else
    echo "FAIL: No differences scenario failed with status $status"
    echo "Output: $output"
    return 1
  fi
  
  if [ -f "$TEMP_DIR/diff_report.txt" ]; then
    echo "PASS: Report file created for no differences"
  else
    echo "FAIL: Report file not created for no differences"
    return 1
  fi
  
  # Should be empty or minimal output
  size=$(wc -c < "$TEMP_DIR/diff_report.txt")
  if [ "$size" -lt 100 ]; then
    echo "PASS: Minimal output for no differences"
  else
    echo "FAIL: Unexpected output size: $size"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}
