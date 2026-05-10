#!/usr/bin/env bash

# Wrapper for diff that handles exit codes properly
diff_wrapper() {
    local output
    output=$(diff -Nru "$@" 2>&1)
    local status=$?
    echo "$output"
    return $status
}

setup_test_directories() {
    TEMP_DIR=$(mktemp -d)
    IMG1_DIR="${TEMP_DIR}/img1"
    IMG2_DIR="${TEMP_DIR}/img2"
    mkdir -p "$IMG1_DIR" "$IMG2_DIR"
    echo "$TEMP_DIR"
}

test_diff_with_wrapper() {
    TEMP_DIR=$(setup_test_directories)
    IMG1_DIR="${TEMP_DIR}/img1"
    IMG2_DIR="${TEMP_DIR}/img2"
    
    # Create test files
    echo "version 1.0" > "$IMG1_DIR/config.txt"
    echo "version 2.0" > "$IMG2_DIR/config.txt"
    
    # Use wrapper function with || true to handle bash_unit's -e flag
    output=$(diff_wrapper "$IMG1_DIR" "$IMG2_DIR" || true)
    status=$?
    
    # For bash_unit, we just check that we got diff output
    if echo "$output" | grep -q "version 1.0" && echo "$output" | grep -q "version 2.0"; then
        echo "PASS: Diff wrapper works"
    else
        echo "FAIL: Diff wrapper missing content"
        echo "Output: $output"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
}

test_inflate_archives_with_wrapper() {
    TEMP_DIR=$(setup_test_directories)
    IMG1_DIR="${TEMP_DIR}/img1"
    
    # Create test archive
    echo "gz content" | gzip > "$IMG1_DIR/test.gz"
    
    # Source functions
    source ./functions_only.sh
    export INFLATE_ARCHIVES="true"
    
    # Test inflation
    cd "$TEMP_DIR"
    inflate_archives "$IMG1_DIR" ".gz"
    
    # Check results
    if [ -d "$IMG1_DIR/test.gz_inflated" ]; then
        echo "PASS: Archive inflation with wrapper works"
    else
        echo "FAIL: Archive inflation with wrapper failed"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
}
