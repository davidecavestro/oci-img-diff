#!/usr/bin/env bash

# Functions-only version with plugin support for testing

# Default values needed for inflate_archives function
INFLATE_ARCHIVES="false"
INFLATE_EXTENSIONS=".jar,.war,.ear,.zip,.tar,.tar.gz,.tgz,.tar.bz2,.tar.xz,.gz,.bz2,.xz,.deb,.rpm"

# Source archive handlers
source ../lib/archive_handlers.sh

# Extract inflate_archives function from main.sh
inflate_archives() {
    local base_dir=$1
    local extensions="$2"
    
    if [ "$INFLATE_ARCHIVES" != "true" ]; then
        return 0
    fi
    
    echo "📦 Inflating archive files..."
    
    # Initialize archive handlers
    init_archive_handlers
    
    # Load plugin handlers if plugins directory exists
    load_plugin_handlers "$(dirname "$0")/../plugins"
    
    # Convert comma-separated extensions to array
    IFS=',' read -ra EXT_ARRAY <<< "$extensions"
    
    # Find and inflate archives
    find "$base_dir" -type f | while read -r file; do
        local filename=$(basename "$file")
        local dirname=$(dirname "$file")
        
        for ext in "${EXT_ARRAY[@]}"; do
            if [[ "$filename" == *"$ext" ]]; then
                local inflated_path="${file}_inflated"
                
                # Skip if already inflated
                if [ -d "$inflated_path" ]; then
                    continue
                fi
                
                # Check if we have a handler for this extension
                if has_archive_handler "$ext"; then
                    echo "  📂 Inflating: $filename"
                    mkdir -p "$inflated_path"
                    
                    # Execute the handler
                    if ! execute_archive_handler "$ext" "$file" "$inflated_path" "$filename"; then
                        echo "  ❌ Failed to inflate: $filename"
                        rm -rf "$inflated_path"
                    fi
                fi
                break
            fi
        done
    done
}
