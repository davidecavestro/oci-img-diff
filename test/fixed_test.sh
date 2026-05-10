#!/usr/bin/env bash

test_fixed() {
  # Force bash shell for bash_unit compatibility
  if [ "$0" = "./bash_unit" ]; then
    echo "Running in bash_unit mode"
  else
    echo "Running in manual mode"
  fi
  
  echo "version 1.0" > /tmp/test1.txt
  echo "version 2.0" > /tmp/test2.txt
  
  output=$(diff -Nru /tmp/test1.txt /tmp/test2.txt 2>&1)
  status=$?
  
  echo "Status: $status"
  
  if [ "$status" -eq 1 ]; then
    echo "PASS: Fixed test"
  else
    echo "FAIL: Fixed test - status: $status"
    return 1
  fi
  
  rm -f /tmp/test1.txt /tmp/test2.txt
}
