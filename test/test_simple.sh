#!/usr/bin/env bash

# Simple test to verify bash_unit works

test_simple_assertion() {
  # Test basic assertion
  if [ "1" = "1" ]; then
    echo "PASS: Simple assertion works"
  else
    echo "FAIL: Simple assertion failed"
    return 1
  fi
}

test_file_operations() {
  # Test file operations
  TEMP_DIR=$(mktemp -d)
  
  if [ -d "$TEMP_DIR" ]; then
    echo "PASS: Temp directory created"
  else
    echo "FAIL: Temp directory not created"
    return 1
  fi
  
  echo "test content" > "$TEMP_DIR/test.txt"
  
  if [ -f "$TEMP_DIR/test.txt" ]; then
    content=$(cat "$TEMP_DIR/test.txt")
    if [ "$content" = "test content" ]; then
      echo "PASS: File operations work"
    else
      echo "FAIL: File content mismatch: $content"
      return 1
    fi
  else
    echo "FAIL: Test file not created"
    return 1
  fi
  
  rm -rf "$TEMP_DIR"
}
