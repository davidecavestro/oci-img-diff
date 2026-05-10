#!/usr/bin/env bash

# Test plugin system for archive handlers
# This file tests the extensibility of the archive handler system

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

test_plugin_loading() {
    # Source the archive handlers
    source ../lib/archive_handlers.sh
    
    # Initialize handlers
    init_archive_handlers
    
    # Check that default handlers are loaded
    if has_archive_handler ".gz" && has_archive_handler ".zip" && has_archive_handler ".tar"; then
        echo "PASS: Default archive handlers loaded"
    else
        echo "FAIL: Default archive handlers not loaded"
        return 1
    fi
}

test_plugin_registration() {
    # Source the archive handlers
    source ../lib/archive_handlers.sh
    
    # Initialize handlers
    init_archive_handlers
    
    # Register a custom handler
    register_archive_handler ".custom" "echo 'Custom handler executed'"
    
    # Check that custom handler is registered
    if has_archive_handler ".custom"; then
        echo "PASS: Custom plugin registration works"
    else
        echo "FAIL: Custom plugin registration failed"
        return 1
    fi
    
    # Check handler command
    local handler_cmd=$(get_archive_handler ".custom")
    if [[ "$handler_cmd" == "echo 'Custom handler executed'" ]]; then
        echo "PASS: Custom handler command stored correctly"
    else
        echo "FAIL: Custom handler command not stored correctly"
        return 1
    fi
}

test_plugin_with_mock_archive() {
    TEMP_DIR=$(setup_test_directories)
    IMG1_DIR="${TEMP_DIR}/img1"
    
    # Source the functions-only version
    source ./functions_with_plugins.sh
    
    # Register a mock plugin for .test files
    register_archive_handler ".test" "echo 'test content' > \"\$inflated_path/test_file.txt\""
    
    # Create a mock archive file
    echo "mock archive content" > "$IMG1_DIR/test.test"
    
    # Test inflation with custom plugin
    export INFLATE_ARCHIVES="true"
    
    cd "$TEMP_DIR"
    inflate_archives "$IMG1_DIR" ".test"
    
    # Check that plugin was executed
    if [ -d "$IMG1_DIR/test.test_inflated" ] && [ -f "$IMG1_DIR/test.test_inflated/test_file.txt" ]; then
        echo "PASS: Plugin with mock archive works"
    else
        echo "FAIL: Plugin with mock archive failed"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
}

test_plugin_directory_loading() {
    # Create a temporary plugin directory
    PLUGIN_DIR=$(mktemp -d)
    
    # Create a test plugin
    cat > "$PLUGIN_DIR/test_plugin.sh" << 'EOF'
#!/usr/bin/env bash
register_archive_handler ".plugin_test" "echo 'Plugin test content' > \"\$inflated_path/plugin_test.txt\""
EOF
    
    # Source the archive handlers
    source ../lib/archive_handlers.sh
    
    # Initialize handlers
    init_archive_handlers
    
    # Load plugins from test directory
    load_plugin_handlers "$PLUGIN_DIR"
    
    # Check that plugin was loaded
    if has_archive_handler ".plugin_test"; then
        echo "PASS: Plugin directory loading works"
    else
        echo "FAIL: Plugin directory loading failed"
        return 1
    fi
    
    # Clean up
    rm -rf "$PLUGIN_DIR"
}

test_plugin_integration_with_diff() {
    TEMP_DIR=$(setup_test_directories)
    IMG1_DIR="${TEMP_DIR}/img1"
    IMG2_DIR="${TEMP_DIR}/img2"
    
    # Source the functions-only version
    source ./functions_with_plugins.sh
    
    # Register plugins for different archive types
    register_archive_handler ".archive1" "echo 'content1' > \"\$inflated_path/file.txt\""
    register_archive_handler ".archive2" "echo 'content2' > \"\$inflated_path/file.txt\""
    
    # Create test archives
    echo "archive1 content" > "$IMG1_DIR/test.archive1"
    echo "archive2 content" > "$IMG2_DIR/test.archive2"
    
    # Test inflation
    export INFLATE_ARCHIVES="true"
    
    cd "$TEMP_DIR"
    inflate_archives "$IMG1_DIR" ".archive1"
    inflate_archives "$IMG2_DIR" ".archive2"
    
    # Generate diff
    output=$(diff_wrapper "$IMG1_DIR" "$IMG2_DIR" || true)
    
    # Check that both archives were processed
    if [ -d "$IMG1_DIR/test.archive1_inflated" ] && [ -d "$IMG2_DIR/test.archive2_inflated" ]; then
        echo "PASS: Plugin integration with diff works"
    else
        echo "FAIL: Plugin integration with diff failed"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
}
