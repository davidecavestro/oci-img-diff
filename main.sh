#!/bin/bash
set -e

# --- Default Values ---
IMAGE1=""
IMAGE2=""
PATH_TO_DIFF="/"
FORMAT="html"
TO_STDOUT="false"
REPORT_NAME="diff_report"
OUT_DIR="/output"
INFLATE_ARCHIVES="false"
INFLATE_EXTENSIONS=".jar,.war,.ear,.zip,.tar,.tar.gz,.tgz,.tar.bz2,.tar.xz,.gz,.bz2,.xz,.deb,.rpm"

usage() {
    echo "Usage: docker run ... <image> [options]"
    echo ""
    echo "Required:"
    echo "  -1, -l, --left <img1>    First container image"
    echo "  -2, -r, --right <img2>   Second container image"
    echo ""
    echo "Options:"
    echo "  -p, --path <path>        Specific path to diff (default: /)"
    echo "  -f, --format <fmt>       Output format: html, text, smart-html, smart-text (default: html)"
    echo "  -o, --output-dir <dir>   Output directory (default: /output)"
    echo "  -s, --stdout             Print output to stdout as well"
    echo "      --inflate             Decompress archive files before comparison (default: disabled)"
    echo "      --inflate-extensions <exts>  Comma-separated list of extensions to inflate (default: .jar,.war,.ear,.zip,.tar,.tar.gz,.tgz,.tar.bz2,.tar.xz,.gz,.bz2,.xz,.deb,.rpm)"
    echo "  -h, --help               Show this help message"
    exit 1
}

# --- Argument Parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --left|-l|-1)
      IMAGE1="$2"
      shift 2
      ;;
    --right|-r|-2)
      IMAGE2="$2"
      shift 2
      ;;
    --path|-p)
      PATH_TO_DIFF="$2"
      shift 2
      ;;
    --format|-f)
      FORMAT="$2"
      shift 2
      ;;
    --output-dir|-o)
      OUT_DIR="$2"
      shift 2
      ;;
    --stdout|-s)
      TO_STDOUT="true"
      shift
      ;;
    --inflate)
      INFLATE_ARCHIVES="true"
      shift
      ;;
    --inflate-extensions)
      INFLATE_EXTENSIONS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Invalid option: $1"
      usage
      ;;
  esac
done

if [ -z "$IMAGE1" ] || [ -z "$IMAGE2" ]; then
    echo "❌ Error: Both --left and --right images are required."
    usage
fi

if [[ "$FORMAT" =~ ^(html|text|smart-html|smart-text)$ ]]; then
    echo "✅ Using format: $FORMAT"
else
    echo "❌ Error: $FORMAT is not a supported format"
    usage
fi

REL_PATH=${PATH_TO_DIFF#/}

# --- OCI Extraction Function ---
extract_oci_fs() {
    local img_name=$1
    local dest=$2
    
    echo "🚚 Exporting $img_name..."
    mkdir -p "$dest/.temp"
    
    # Export OCI archive from registry
    if ! regctl image export --platform local "$img_name" > "$dest/export.tar"; then
        echo "❌ Error: Failed to export $img_name"
        exit 1
    fi
    
    tar -xf "$dest/export.tar" -C "$dest/.temp"

    echo "📂 Flattening OCI layers for $img_name..."
    # Parse OCI index to find the manifest blob
    MANIFEST=$(jq -r '.manifests[0].digest | sub("sha256:"; "blobs/sha256/")' "$dest/.temp/index.json")
    
    # Extract each layer blob listed in the manifest
    jq -r '.layers[].digest | sub("sha256:"; "blobs/sha256/")' "$dest/.temp/$MANIFEST" | while read -r layer_path; do
        if [ -f "$dest/.temp/$layer_path" ]; then
            tar -xf "$dest/.temp/$layer_path" -C "$dest" 2>/dev/null || true
        fi
    done
    
    rm -rf "$dest/.temp" "$dest/export.tar"
}

# --- Archive Handlers ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/archive_handlers.sh"

# --- Archive Inflation Function ---
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
    load_plugin_handlers "$(dirname "$0")/plugins"
    
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

# --- Main Execution ---
mkdir -p /tmp/img1 /tmp/img2
extract_oci_fs "$IMAGE1" "/tmp/img1"
extract_oci_fs "$IMAGE2" "/tmp/img2"

# Inflate archives if requested
inflate_archives "/tmp/img1" "$INFLATE_EXTENSIONS"
inflate_archives "/tmp/img2" "$INFLATE_EXTENSIONS"

DIR1="/tmp/img1/$REL_PATH"
DIR2="/tmp/img2/$REL_PATH"

if [ ! -d "$DIR1" ] || [ ! -d "$DIR2" ]; then
    echo "❌ Error: Path /$REL_PATH not found in one or both images."
    exit 1
fi

# --- Output Logic ---
mkdir -p "$OUT_DIR"
case "$FORMAT" in
    "smart-text")
        echo "🔍 Running Difftastic (Structural Text mode)..."
        difft --skip-unchanged --color always "$DIR1" "$DIR2" > "$OUT_DIR/${REPORT_NAME}.txt"
        [ "$TO_STDOUT" == "true" ] && cat "$OUT_DIR/${REPORT_NAME}.txt"
        echo "✅ Textual report saved to ${REPORT_NAME}.txt"
        ;;

    "smart-html")
        echo "🔍 Running Difftastic (Structural HTML mode)..."
        # Removed --full and used the standard pipe. 
        # ansi2html (pip version) creates a partial by default, 
        # or we can use the 'man' style or just let it wrap.
        difft --skip-unchanged --color always "$DIR1" "$DIR2" | ansi2html > "$OUT_DIR/${REPORT_NAME}.html"
        
        [ "$TO_STDOUT" == "true" ] && difft --color always "$DIR1" "$DIR2"
        echo "✅ Structural HTML report saved to ${REPORT_NAME}.html"
        ;;

    "text")
        echo "🔍 Running Standard Diff (Text mode)..."
        # Generate standard unified diff
        diff -Nru --no-dereference "$DIR1" "$DIR2" > "$OUT_DIR/${REPORT_NAME}.txt" || true
        echo "✅ Textual report saved to ${REPORT_NAME}.txt"
        ;;

    "html")
        echo "🔍 Running Standard Diff (HTML mode)..."
        # Generate standard unified diff
        diff -Nru --no-dereference "$DIR1" "$DIR2" > /tmp/combined.diff || true
        
        if [ ! -s /tmp/combined.diff ]; then
            echo "🎉 No differences found!"
            echo "<h1>No changes detected at /$REL_PATH</h1>" > "$OUT_DIR/${REPORT_NAME}.html"
        else
            # Preprocess diff to handle binary files properly
            echo "📝 Preprocessing diff for binary file compatibility..."
            ./preprocess-diff.sh /tmp/combined.diff /tmp/processed.diff
            
            diff2html -i file -s side --summary open \
                --title "Standard Diff: $IMAGE1 vs $IMAGE2" \
                -f html -F "$OUT_DIR/${REPORT_NAME}.html" \
                -- /tmp/processed.diff
            [ "$TO_STDOUT" == "true" ] && cat /tmp/combined.diff
            echo "✅ HTML report saved to ${REPORT_NAME}.html"
        fi
        ;;
esac

echo "🏁 Process complete!"