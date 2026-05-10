#!/usr/bin/env bash

# Extract only the functions from main.sh
# This isolates functions from argument parsing logic

# Default values needed for inflate_archives function
INFLATE_ARCHIVES="false"
INFLATE_EXTENSIONS=".jar,.war,.ear,.zip,.tar,.tar.gz,.tgz,.tar.bz2,.tar.xz,.gz,.bz2,.xz,.deb,.rpm"

# Extract inflate_archives function
inflate_archives() {
    local base_dir=$1
    local extensions="$2"
    
    if [ "$INFLATE_ARCHIVES" != "true" ]; then
        return 0
    fi
    
    echo "📦 Inflating archive files..."
    
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
                
                echo "  📂 Inflating: $filename"
                mkdir -p "$inflated_path"
                
                case "$ext" in
                    .jar|.war|.ear|.zip)
                        if command -v unzip >/dev/null 2>&1; then
                            unzip -q "$file" -d "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .tar)
                        if command -v tar >/dev/null 2>&1; then
                            tar -xf "$file" -C "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .tar.gz|.tgz)
                        if command -v tar >/dev/null 2>&1; then
                            tar -xzf "$file" -C "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .tar.bz2)
                        if command -v tar >/dev/null 2>&1; then
                            tar -xjf "$file" -C "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .tar.xz)
                        if command -v tar >/dev/null 2>&1; then
                            tar -xJf "$file" -C "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .gz)
                        if command -v gunzip >/dev/null 2>&1; then
                            gunzip -c "$file" > "$inflated_path/${filename%$ext}" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .bz2)
                        if command -v bunzip2 >/dev/null 2>&1; then
                            bunzip2 -c "$file" > "$inflated_path/${filename%$ext}" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .xz)
                        if command -v unxz >/dev/null 2>&1; then
                            unxz -c "$file" > "$inflated_path/${filename%$ext}" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .deb)
                        if command -v dpkg-deb >/dev/null 2>&1; then
                            dpkg-deb -x "$file" "$inflated_path" 2>/dev/null || rm -rf "$inflated_path"
                        fi
                        ;;
                    .rpm)
                        if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
                            cd "$inflated_path" && rpm2cpio "$file" | cpio -idm 2>/dev/null || rm -rf "$inflated_path"
                            cd - >/dev/null
                        fi
                        ;;
                esac
                break
            fi
        done
    done
}
