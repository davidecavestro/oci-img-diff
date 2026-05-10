#!/usr/bin/env bash

# Test helper functions for BATS tests

# Create a temporary directory for tests
setup_temp_dir() {
    export TEMP_DIR=$(mktemp -d)
    export TEST_DIR1="${TEMP_DIR}/img1"
    export TEST_DIR2="${TEMP_DIR}/img2"
    mkdir -p "$TEST_DIR1" "$TEST_DIR2"
}

# Clean up temporary directory
cleanup_temp_dir() {
    rm -rf "$TEMP_DIR"
}

# Create test archive files
create_test_archives() {
    local base_dir="$1"
    
    # Create gz file
    echo "gz content" | gzip > "${base_dir}/test.gz"
    
    # Create zip file
    mkdir -p "${base_dir}/subdir"
    echo "zip content" > "${base_dir}/subdir/file.txt"
    cd "$base_dir" && zip -r test.zip subdir/ && cd - >/dev/null
    
    # Create tar file
    mkdir -p "${base_dir}/tar_subdir"
    echo "tar content" > "${base_dir}/tar_subdir/file.txt"
    cd "$base_dir" && tar -cf test.tar tar_subdir/ && cd - >/dev/null
    
    # Create tar.gz file
    cd "$base_dir" && tar -czf test.tar.gz tar_subdir/ && cd - >/dev/null
}

# Check if command exists in container
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for file to exist (with timeout)
wait_for_file() {
    local file="$1"
    local timeout="${2:-10}"
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -f "$file" ]; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

# Get file count in directory
file_count() {
    find "$1" -type f | wc -l
}

# Get directory count in directory
dir_count() {
    find "$1" -type d | wc -l
}
