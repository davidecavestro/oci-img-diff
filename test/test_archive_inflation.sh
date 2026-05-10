#!/usr/bin/env bash

# Test archive inflation functionality
# This file tests the inflate_archives function and related features

test_inflate_archives_function_exists() {
  # Source the main script to get the function
  source ../main.sh
  
  # Check if function exists
  if type -t inflate_archives | grep -q "function"; then
    echo "PASS: inflate_archives function exists"
  else
    echo "FAIL: inflate_archives function does not exist"
    return 1
  fi
}

test_inflate_archives_disabled_by_default() {
  export INFLATE_ARCHIVES="false"
  source ../main.sh
  
  # Create test files
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  echo "test content" | gzip > "$TEMP_DIR/img1/test.gz"
  
  # Run function (should do nothing)
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # No inflated directories should be created
  assert_equals "$(find "$TEMP_DIR/img1" -name "*_inflated" -type d | wc -l)" "0"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_gzip_files() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  
  # Create test gz file
  echo "test content" | gzip > "$TEMP_DIR/img1/test.gz"
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # Check inflated directory exists
  assert "[ -d '$TEMP_DIR/img1/test.gz_inflated' ]"
  
  # Check content is decompressed
  assert "[ -f '$TEMP_DIR/img1/test.gz_inflated/test' ]"
  assert_equals "$(cat "$TEMP_DIR/img1/test.gz_inflated/test")" "test content"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_zip_files() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1/subdir"
  
  # Create test zip file
  echo "zip content" > "$TEMP_DIR/img1/subdir/file.txt"
  cd "$TEMP_DIR/img1" && zip -r test.zip subdir/ && cd - >/dev/null
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".zip"
  
  # Check inflated directory exists
  assert "[ -d '$TEMP_DIR/img1/test.zip_inflated' ]"
  
  # Check content is extracted
  assert "[ -f '$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt' ]"
  assert_equals "$(cat "$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt")" "zip content"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_tar_files() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1/subdir"
  
  # Create test tar file
  echo "tar content" > "$TEMP_DIR/img1/subdir/file.txt"
  cd "$TEMP_DIR/img1" && tar -cf test.tar subdir/ && cd - >/dev/null
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".tar"
  
  # Check inflated directory exists
  assert "[ -d '$TEMP_DIR/img1/test.tar_inflated' ]"
  
  # Check content is extracted
  assert "[ -f '$TEMP_DIR/img1/test.tar_inflated/subdir/file.txt' ]"
  assert_equals "$(cat "$TEMP_DIR/img1/test.tar_inflated/subdir/file.txt")" "tar content"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_multiple_extensions() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
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
  assert "[ -d '$TEMP_DIR/img1/test.gz_inflated' ]"
  assert "[ -d '$TEMP_DIR/img1/test.zip_inflated' ]"
  
  # Check content of both
  assert_equals "$(cat "$TEMP_DIR/img1/test.gz_inflated/test")" "gz content"
  assert_equals "$(cat "$TEMP_DIR/img1/test.zip_inflated/subdir/file.txt")" "zip content"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_skips_already_inflated_files() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  
  # Create test file and manually inflate it
  echo "test content" | gzip > "$TEMP_DIR/img1/test.gz"
  mkdir -p "$TEMP_DIR/img1/test.gz_inflated"
  echo "existing content" > "$TEMP_DIR/img1/test.gz_inflated/test"
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # Content should remain unchanged
  assert_equals "$(cat "$TEMP_DIR/img1/test.gz_inflated/test")" "existing content"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_corrupted_archives_gracefully() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1"
  
  # Create corrupted zip file
  echo "not a zip file" > "$TEMP_DIR/img1/corrupted.zip"
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".zip"
  
  # Inflated directory should be removed due to corruption
  assert "[ ! -d '$TEMP_DIR/img1/corrupted.zip_inflated' ]"
  
  rm -rf "$TEMP_DIR"
}

test_inflate_archives_handles_nested_directories() {
  export INFLATE_ARCHIVES="true"
  source ../main.sh
  
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/img1/deep/nested/path"
  
  # Create nested structure with archive
  echo "nested content" | gzip > "$TEMP_DIR/img1/deep/nested/path/test.gz"
  
  cd "$TEMP_DIR"
  inflate_archives "$TEMP_DIR/img1" ".gz"
  
  # Check inflated directory exists in nested location
  assert "[ -d '$TEMP_DIR/img1/deep/nested/path/test.gz_inflated' ]"
  assert "[ -f '$TEMP_DIR/img1/deep/nested/path/test.gz_inflated/test' ]"
  assert_equals "$(cat "$TEMP_DIR/img1/deep/nested/path/test.gz_inflated/test")" "nested content"
  
  rm -rf "$TEMP_DIR"
}
