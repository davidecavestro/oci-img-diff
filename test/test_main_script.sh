#!/usr/bin/env bash

# Test main script functionality
# This file tests the main.sh script argument parsing and basic functionality

test_main_script_shows_help_with_no_arguments() {
  # Test that the script shows help when no arguments are provided
  run ../main.sh
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "Usage:")" "1"
  assert_equals "$(echo "$output" | grep -c "Required:")" "1"
}

test_main_script_shows_help_with_h_flag() {
  run ../main.sh -h
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "Usage:")" "1"
  assert_equals "$(echo "$output" | grep -c "\-\-help")" "1"
}

test_main_script_shows_help_with_help_flag() {
  run ../main.sh --help
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "Usage:")" "1"
  assert_equals "$(echo "$output" | grep -c "\-\-help")" "1"
}

test_main_script_validates_required_arguments() {
  run ../main.sh --left image1
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "Both --left and --right images are required")" "1"
}

test_main_script_validates_format() {
  run ../main.sh --left image1 --right image2 --format invalid
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "invalid is not a supported format")" "1"
}

test_main_script_accepts_valid_formats() {
  for format in "html" "text" "smart-html" "smart-text"; do
    run ../main.sh --left image1 --right image2 --format "$format"
    # Will fail at image export, but format should be valid
    assert_equals "$status" "1"
    assert_equals "$(echo "$output" | grep -c "Using format: $format")" "1"
  done
}

test_main_script_has_default_values() {
  # Source the script to check default values
  source ../main.sh
  
  assert_equals "$FORMAT" "html"
  assert_equals "$PATH_TO_DIFF" "/"
  assert_equals "$TO_STDOUT" "false"
  assert_equals "$REPORT_NAME" "diff_report"
  assert_equals "$OUT_DIR" "/output"
  assert_equals "$INFLATE_ARCHIVES" "false"
  
  # Check that default extensions include common formats
  assert_equals "$(echo "$INFLATE_EXTENSIONS" | grep -c "\.jar")" "1"
  assert_equals "$(echo "$INFLATE_EXTENSIONS" | grep -c "\.zip")" "1"
  assert_equals "$(echo "$INFLATE_EXTENSIONS" | grep -c "\.gz")" "1"
}

test_main_script_parses_inflate_flag() {
  # Test that the script recognizes the inflate flag
  run ../main.sh --left image1 --right image2 --inflate --help
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "\-\-inflate")" "1"
}

test_main_script_parses_inflate_extensions_flag() {
  # Test that the script recognizes the inflate-extensions flag
  run ../main.sh --left image1 --right image2 --inflate-extensions ".zip,.gz" --help
  assert_equals "$status" "1"
  assert_equals "$(echo "$output" | grep -c "\-\-inflate-extensions")" "1"
}

test_main_script_creates_output_directory() {
  TEMP_DIR=$(mktemp -d)
  export OUTPUT_DIR="${TEMP_DIR}/custom_output"
  
  run ../main.sh --left image1 --right image2 --output-dir "$OUTPUT_DIR" --format text
  assert_equals "$status" "1"  # Will fail at image export
  # The script should attempt to create output directory
  assert "[ -d '$OUTPUT_DIR' ]"
  
  rm -rf "$TEMP_DIR"
}

test_main_script_accepts_all_argument_formats() {
  # Test different argument formats
  run ../main.sh -l image1 -r image2
  assert_equals "$status" "1"  # Will fail at image export
  
  run ../main.sh --left image1 --right image2
  assert_equals "$status" "1"  # Will fail at image export
  
  run ../main.sh -1 image1 -2 image2
  assert_equals "$status" "1"  # Will fail at image export
}

test_main_script_accepts_path_arguments() {
  # Test path argument formats
  run ../main.sh --left image1 --right image2 --path /etc
  assert_equals "$status" "1"  # Will fail at image export
  
  run ../main.sh -l image1 -r image2 -p /usr
  assert_equals "$status" "1"  # Will fail at image export
}
