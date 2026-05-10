#!/usr/bin/env bash

test_final_debug() {
  echo "=== Debug bash_unit environment ==="
  echo "Current shell: $0"
  echo "Bash version: $BASH_VERSION"
  
  echo "version 1.0" > /tmp/test1.txt
  echo "version 2.0" > /tmp/test2.txt
  
  echo "=== About to run diff ==="
  output=$(diff -Nru /tmp/test1.txt /tmp/test2.txt 2>&1)
  status=$?
  
  echo "=== After diff ==="
  echo "Status: $status"
  echo "Output: $output"
  
  if [ "$status" -eq 1 ]; then
    echo "PASS: Final test"
  else
    echo "FAIL: Final test - status: $status"
    return 1
  fi
  
  rm -f /tmp/test1.txt /tmp/test2.txt
}
