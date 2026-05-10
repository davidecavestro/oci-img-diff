#!/usr/bin/env bash

# Test only the functions from main.sh without executing the main script
# This isolates the function testing from argument parsing

setup_test_environment() {
  # Create a temporary main script with only functions
  grep -A 1000 "^# --- Archive Inflation Function ---" ../main.sh | grep -B 1000 "^# --- Main Execution ---" | head -n -1 > /tmp/functions_only.sh
  source /tmp/functions_only.sh
}

test_inflate_archives_function_exists() {
  setup_test_environment
  
  # Check if function exists
  if type -t inflate_archives | grep -q "function"; then
    echo "PASS: inflate_archives function exists"
  else
    echo "FAIL: inflate_archives function does not exist"
    return 1
  fi
}

test_inflate_archives_disabled_by_default() {
  setup_test_environment
  
  export INFLATE_ARCHIVES="false"
  
  # Create test files
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  echo "test content" | gzip > "$TEMP_DIR/img1/test.gz"
  
  # Run function (should do nothing)
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # No inflated directories should be created
  inflated_count=$(find "$TEMP_DIR/img1" -name "*_inflated" -type d | wc -l)
  if [ "$inflated_count" -eq 0 ]; then
    echo "PASS: No directories created when inflation disabled"
  else
    echo "FAIL: Found $inflated_count inflated directories when disabled"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_gzip_files() {
  setup_test_environment
  
  export INFLATE_ARCHIVES="true"
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  
  # Create test gz file
  echo "test content" | gzip > "$TEMP_DIR/img1/test.gz"
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # Check inflated directory exists
  if [ -d "$TEMP_DIR/img1/test.gz_inflated" ]; then
    echo "PASS: Gzip inflated directory created"
  else
    echo "FAIL: Gzip inflated directory not created"
    return 1
  fi
  
  # Check content is decompressed
  if [ -f "$TEMP_DIR/img1/test.gz_inflated/test" ]; then
    content=$(cat "$TEMP_DIR/img1/test.gz_inflated/test")
    if [ "$content" = "test content" ]; then
      echo "PASS: Gzip content correctly decompressed"
    else
      echo "FAIL: Gzip content mismatch: $content"
      return 1
    fi
  else
    echo "FAIL: Decompressed file not found"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_zip_files() {
  setup_test_environment
  
  export INFLATE_ARCHIVES="true"
  
  # Skip if zip command is not available
  if ! command -v zip >/dev/null 2>&1; then
    echo "SKIP: zip command not available"
    return 0
  fi
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1/subdir"
  
  # Create test zip file
  echo "zip content" > "$TEMP_DIR/img1/subdir/file.txt"
  cd "$TEMP_DIR/img1" && zip -r test.zip subdir/ && cd - >/dev/null
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".zip"
  
  # Check inflated directory exists
  if [ -d "$TEMP_DIR/img1/test.zip_inflated" ]; then
    echo "PASS: Zip inflated directory created"
  else
    echo "FAIL: Zip inflated directory not created"
    return 1
  fi
  
  # Check content is extracted
  if [ -f "$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt" ]; then
    content=$(cat "$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt")
    if [ "$content" = "zip content" ]; then
      echo "PASS: Zip content correctly extracted"
    else
      echo "FAIL: Zip content mismatch: $content"
      return 1
    fi
  else
    echo "FAIL: Extracted file not found"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_multiple_extensions() {
  setup_test_environment
  
  export INFLATE_ARCHIVES="true"
  
  # Skip if zip command is not available
  if ! command -v zip >/dev/null 2>&1; then
    echo "SKIP: zip command not available for multiple extensions test"
    return 0
  fi
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  
  # Create multiple test files
  echo "gz content" | gzip > "$TEMP_DIR/img1/test.gz"
  mkdir -p "$TEMP_DIR/img1/subdir"
  echo "zip content" > "$TEMP_DIR/img1/subdir/file.txt"
  cd "$TEMP_DIR/img1" && zip -r test.zip subdir/ && cd - >/dev/null
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz,.zip"
  
  # Both inflated directories should exist
  gz_ok=false
  zip_ok=false
  
  if [ -d "$TEMP_DIR/img1/test.gz_inflated" ]; then
    content=$(cat "$TEMP_DIR/img1/test.gz_inflated/test")
    if [ "$content" = "gz content" ]; then
      gz_ok=true
    fi
  fi
  
  if [ -d "$TEMP_DIR/img1/test.zip_inflated" ]; then
    content=$(cat "$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt")
    if [ "$content" = "zip content" ]; then
      zip_ok=true
    fi
  fi
  
  if [ "$gz_ok" = true ] && [ "$zip_ok" = true ]; then
    echo "PASS: Multiple extensions handled correctly"
  else
    echo "FAIL: Multiple extensions not handled properly"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}
