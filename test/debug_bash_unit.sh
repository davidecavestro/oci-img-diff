#!/usr/bin/env bash

echo "=== Testing bash_unit variable capture ==="

test_bash_unit_issue() {
  echo "version 1.0" > /tmp/test1.txt
  echo "version 2.0" > /tmp/test2.txt
  
  echo "Before diff command"
  output=$(diff -Nru /tmp/test1.txt /tmp/test2.txt 2>&1); status=$?
  echo "After diff command"
  echo "Status: $status"
  echo "Output length: ${#output}"
  
  if [ "$status" -eq 1 ]; then
    echo "PASS: Status check"
  else
    echo "FAIL: Status check - got $status"
    return 1
  fi
  
  if echo "$output" | grep -q "version 1.0"; then
    echo "PASS: Content check 1"
  else
    echo "FAIL: Content check 1"
    return 1
  fi
  
  if echo "$output" | grep -q "version 2.0"; then
    echo "PASS: Content check 2"
  else
    echo "FAIL: Content check 2"
    return 1
  fi
  
  rm -f /tmp/test1.txt /tmp/test2.txt
}

echo "=== Running test manually ==="
test_bash_unit_issue

echo "=== Running test with bash_unit ==="
# Simulate bash_unit environment
set -e
test_bash_unit_issue || echo "Test failed in bash_unit mode"
