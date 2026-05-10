#!/usr/bin/env bash

# Isolated tests - mock img1/img2 directories
# This file tests functionality without pulling real container images

setup_test_directories() {
  TEMP_DIR=$(mktemp -d)
  IMG1_DIR="${TEMP_DIR}/img1"
  IMG2_DIR="${TEMP_DIR}/img2"
  mkdir -p "$IMG1_DIR" "$IMG2_DIR"
  echo "$TEMP_DIR"
}

test_inflate_archives_with_mock_data() {
  TEMP_DIR=$(setup_test_directories)
  IMG1_DIR="${TEMP_DIR}/img1"
  IMG2_DIR="${TEMP_DIR}/img2"
  
  # Create test directories with archives
  mkdir -p "$IMG1_DIR/subdir"
  echo "content1" > "$IMG1_DIR/file1.txt"
  echo "gz content" | gzip > "$IMG1_DIR/test.gz"
  
  mkdir -p "$IMG2_DIR/subdir"
  echo "content2" > "$IMG2_DIR/file1.txt"
  echo "gz content v2" | gzip > "$IMG2_DIR/test.gz"
  
  # Source main script functions
  source ../main.sh
  
  export INFLATE_ARCHIVES="true"
  
  # Test inflation on both directories
  cd "$TEMP_DIR"
  inflate_archives "$IMG1_DIR" ".gz"
  inflate_archives "$IMG2_DIR" ".gz"
  
  # Check inflated directories exist
  if [ -d "$IMG1_DIR/test.gz_inflated" ] && [ -d "$IMG2_DIR/test.gz_inflated" ]; then
    echo "PASS: Archive inflation works with mock data"
  else
    echo "FAIL: Archive inflation failed with mock data"
    return 1
  fi
  
  # Check content was decompressed
  content1=$(cat "$IMG1_DIR/test.gz_inflated/test")
  content2=$(cat "$IMG2_DIR/test.gz_inflated/test")
  
  if [ "$content1" = "gz content" ] && [ "$content2" = "gz content v2" ]; then
    echo "PASS: Archive content correctly decompressed"
  else
    echo "FAIL: Archive content not correctly decompressed"
    echo "Content1: $content1"
    echo "Content2: $content2"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_diff_generation_with_mock_data() {
  TEMP_DIR=$(setup_test_directories)
  IMG1_DIR="${TEMP_DIR}/img1"
  IMG2_DIR="${TEMP_DIR}/img2"
  
  # Create test directories with different content
  echo "version 1.0" > "$IMG1_DIR/config.txt"
  echo "version 2.0" > "$IMG2_DIR/config.txt"
  
  # Create subdirectories
  mkdir -p "$IMG1_DIR/subdir"
  mkdir -p "$IMG2_DIR/subdir"
  echo "old content" > "$IMG1_DIR/subdir/data.txt"
  echo "new content" > "$IMG2_DIR/subdir/data.txt"
  
  # Generate diff
  output=$(diff -Nru --no-dereference "$IMG1_DIR" "$IMG2_DIR" 2>&1)
  status=$?
  
  if [ "$status" -eq 1 ]; then  # diff returns 1 when differences found
    echo "PASS: Diff generation works with mock data"
  else
    echo "FAIL: Diff generation failed with mock data"
    return 1
  fi
  
  # Check diff contains expected changes
  if echo "$output" | grep -q "version 1.0" && echo "$output" | grep -q "version 2.0"; then
    echo "PASS: Diff contains expected content differences"
  else
    echo "FAIL: Diff missing expected content differences"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_archive_inflation_integration() {
  TEMP_DIR=$(setup_test_directories)
  IMG1_DIR="${TEMP_DIR}/img1"
  IMG2_DIR="${TEMP_DIR}/img2"
  
  # Create complex test scenario
  mkdir -p "$IMG1_DIR/lib"
  echo "original content" > "$IMG1_DIR/lib/app.jar"
  echo "config v1" > "$IMG1_DIR/config.properties"
  
  mkdir -p "$IMG2_DIR/lib"
  echo "updated content" > "$IMG2_DIR/lib/app.jar"
  echo "config v2" > "$IMG2_DIR/config.properties"
  
  # Source main script functions
  source ../main.sh
  
  export INFLATE_ARCHIVES="true"
  
  # Inflate archives
  cd "$TEMP_DIR"
  inflate_archives "$IMG1_DIR" ".jar"
  inflate_archives "$IMG2_DIR" ".jar"
  
  # Generate diff
  output=$(diff -Nru --no-dereference "$IMG1_DIR" "$IMG2_DIR" 2>&1)
  
  # Check that both original files and inflated archives are in diff
  if echo "$output" | grep -q "config.properties" && echo "$output" | grep -q "app.jar"; then
    echo "PASS: Archive inflation integration works"
  else
    echo "FAIL: Archive inflation integration failed"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}

test_multiple_archive_types() {
  TEMP_DIR=$(setup_test_directories)
  IMG1_DIR="${TEMP_DIR}/img1"
  
  # Create multiple archive types
  echo "tar content" > "$IMG1_DIR/data.txt"
  tar -czf "$IMG1_DIR/archive.tar.gz" -C "$IMG1_DIR" data.txt
  
  # Source main script functions
  source ../main.sh
  
  export INFLATE_ARCHIVES="true"
  
  # Test multiple extensions
  cd "$TEMP_DIR"
  inflate_archives "$IMG1_DIR" ".tar.gz,.gz"
  
  # Check both archive types would be processed
  if [ -d "$IMG1_DIR/archive.tar.gz_inflated" ]; then
    echo "PASS: Multiple archive types handled"
  else
    echo "FAIL: Multiple archive types not handled"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}
