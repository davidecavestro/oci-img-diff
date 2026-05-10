#!/usr/bin/env bash

# Modular Archive Handlers
# This file provides a plugin system for archive decompression

# Registry of archive handlers
declare -A ARCHIVE_HANDLERS

# Register a new archive handler
# Usage: register_archive_handler <extension> <command>
register_archive_handler() {
    local ext="$1"
    local cmd="$2"
    ARCHIVE_HANDLERS["$ext"]="$cmd"
}

# Initialize default archive handlers
init_archive_handlers() {
    # ZIP/JAR/WAR/EAR files
    register_archive_handler ".jar" "unzip -q \"\$file\" -d \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".war" "unzip -q \"\$file\" -d \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".ear" "unzip -q \"\$file\" -d \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".zip" "unzip -q \"\$file\" -d \"\$inflated_path\" 2>/dev/null"
    
    # TAR files
    register_archive_handler ".tar" "tar -xf \"\$file\" -C \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".tar.gz" "tar -xzf \"\$file\" -C \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".tgz" "tar -xzf \"\$file\" -C \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".tar.bz2" "tar -xjf \"\$file\" -C \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".tar.xz" "tar -xJf \"\$file\" -C \"\$inflated_path\" 2>/dev/null"
    
    # Compressed files
    register_archive_handler ".gz" "gunzip -c \"\$file\" > \"\$inflated_path/\${filename%$ext}\" 2>/dev/null"
    register_archive_handler ".bz2" "bunzip2 -c \"\$file\" > \"\$inflated_path/\${filename%$ext}\" 2>/dev/null"
    register_archive_handler ".xz" "unxz -c \"\$file\" > \"\$inflated_path/\${filename%$ext}\" 2>/dev/null"
    
    # Package files
    register_archive_handler ".deb" "dpkg-deb -x \"\$file\" \"\$inflated_path\" 2>/dev/null"
    register_archive_handler ".rpm" "cd \"\$inflated_path\" && rpm2cpio \"\$file\" | cpio -idm 2>/dev/null"
}

# Get handler for a specific extension
get_archive_handler() {
    local ext="$1"
    echo "${ARCHIVE_HANDLERS[$ext]}"
}

# List all registered handlers
list_archive_handlers() {
    for ext in "${!ARCHIVE_HANDLERS[@]}"; do
        echo "$ext: ${ARCHIVE_HANDLERS[$ext]}"
    done
}

# Check if handler exists for extension
has_archive_handler() {
    local ext="$1"
    [[ -n "${ARCHIVE_HANDLERS[$ext]}" ]]
}

# Execute archive handler
execute_archive_handler() {
    local ext="$1"
    local file="$2"
    local inflated_path="$3"
    local filename="$4"
    
    local handler_cmd="${ARCHIVE_HANDLERS[$ext]}"
    if [[ -n "$handler_cmd" ]]; then
        eval "$handler_cmd" || return 1
        return 0
    fi
    return 1
}

# Load custom handlers from plugins directory
load_plugin_handlers() {
    local plugin_dir="${1:-./plugins}"
    
    if [[ -d "$plugin_dir" ]]; then
        for plugin in "$plugin_dir"/*.sh; do
            if [[ -f "$plugin" ]]; then
                echo "Loading plugin: $(basename "$plugin")"
                source "$plugin"
            fi
        done
    fi
}
