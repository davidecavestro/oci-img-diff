#!/usr/bin/env bash

test_minimal_diff() {
  echo "version 1.0" > /tmp/test1.txt
  echo "version 2.0" > /tmp/test2.txt
  
  output=$(diff -Nru /tmp/test1.txt /tmp/test2.txt 2>&1); status=$?
  
  if [ "$status" -eq 1 ]; then
    echo "PASS: Minimal diff test"
  else
    echo "FAIL: Minimal diff test, status: $status"
    return 1
  fi
  
  rm -f /tmp/test1.txt /tmp/test2.txt
}
