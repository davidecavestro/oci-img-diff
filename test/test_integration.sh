#!/usr/bin/env bash

# Integration tests
# This file tests the complete workflow with Docker containers

test_integration_basic_text_format_comparison() {
  TEMP_DIR=$(mktemp -d)
  
  # Build test image first
  cd .. && docker build -t oci-img-diff-test . >/dev/null 2>&1
  cd test
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.txt' ]"
  
  # Check that diff contains expected content
  assert_equals "$(grep -c "alpine-release" "$TEMP_DIR/diff_report.txt")" "1"
  
  rm -rf "$TEMP_DIR"
}

test_integration_html_format_with_binary_files() {
  TEMP_DIR=$(mktemp -d)
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format html \
    --path /bin
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.html' ]"
  
  # Check that HTML contains binary file differences
  assert_equals "$(grep -c "Binary file (content differs)" "$TEMP_DIR/diff_report.html")" "1"
  
  rm -rf "$TEMP_DIR"
}

test_integration_smart_text_format() {
  TEMP_DIR=$(mktemp -d)
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format smart-text \
    --path /etc
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.txt' ]"
  
  # Check that difftastic output is generated
  assert_equals "$(wc -l < "$TEMP_DIR/diff_report.txt")" "0"
  
  rm -rf "$TEMP_DIR"
}

test_integration_smart_html_format() {
  TEMP_DIR=$(mktemp -d)
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format smart-html \
    --path /etc
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.html' ]"
  
  # Check that HTML is generated
  assert_equals "$(grep -c "<html" "$TEMP_DIR/diff_report.html")" "1"
  
  rm -rf "$TEMP_DIR"
}

test_integration_custom_output_directory() {
  TEMP_DIR=$(mktemp -d)
  CUSTOM_DIR="${TEMP_DIR}/custom_output"
  mkdir -p "$CUSTOM_DIR"
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --output-dir /output/custom_output
  
  assert_equals "$status" "0"
  assert "[ -f '$CUSTOM_DIR/diff_report.txt' ]"
  
  rm -rf "$TEMP_DIR"
}

test_integration_stdout_output() {
  run docker run --rm \
    -v /tmp:/output \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /etc \
    --stdout
  
  assert_equals "$status" "0"
  assert_equals "$(echo "$output" | grep -c "alpine-release")" "1"
}

test_integration_no_differences_found() {
  TEMP_DIR=$(mktemp -d)
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.22.2 \
    --format text
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.txt' ]"
  
  # Should be empty or minimal output
  assert_equals "$(wc -c < "$TEMP_DIR/diff_report.txt")" "0"
  
  rm -rf "$TEMP_DIR"
}

test_integration_archive_inflation_feature() {
  TEMP_DIR=$(mktemp -d)
  
  # Create a test image with archives
  docker run --rm alpine:3.22.2 sh -c "
    echo 'test content' | gzip > /tmp/test.gz
    echo 'zip content' > /tmp/file.txt
    zip -r /tmp/test.zip /tmp/file.txt
  " || true
  
  run docker run --rm \
    -v "$TEMP_DIR:/output" \
    oci-img-diff-test \
    --left alpine:3.22.2 \
    --right alpine:3.23.4 \
    --format text \
    --path /tmp \
    --inflate
  
  assert_equals "$status" "0"
  assert "[ -f '$TEMP_DIR/diff_report.txt' ]"
  
  rm -rf "$TEMP_DIR"
}
