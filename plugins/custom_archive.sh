#!/usr/bin/env bash

# Custom Archive Plugin Example
# This plugin demonstrates how to add support for custom archive formats

# Register a custom archive handler for .7z files
if command -v 7z >/dev/null 2>&1; then
    register_archive_handler ".7z" "7z x \"\$file\" -o\"\$inflated_path\" 2>/dev/null"
fi

# Register a custom archive handler for .rar files (if available)
if command -v unrar >/dev/null 2>&1; then
    register_archive_handler ".rar" "unrar x \"\$file\" \"\$inflated_path\" 2>/dev/null"
fi

# Register a custom handler for .lha files (if available)
if command -v lha >/dev/null 2>&1; then
    register_archive_handler ".lha" "lha x=\"\$inflated_path\" \"\$file\" 2>/dev/null"
fi

# Custom handler for .iso files (mount and copy)
if command -v mount >/dev/null 2>&1 && command -v cp >/dev/null 2>&1; then
    register_archive_handler ".iso" "
        local temp_mount=\"\$inflated_path.temp_mount\"
        mkdir -p \"\$temp_mount\"
        mount -o loop,ro \"\$file\" \"\$temp_mount\" 2>/dev/null && {
            cp -r \"\$temp_mount\"/* \"\$inflated_path/\" 2>/dev/null
            umount \"\$temp_mount\" 2>/dev/null
        }
        rmdir \"\$temp_mount\" 2>/dev/null
    "
fi
