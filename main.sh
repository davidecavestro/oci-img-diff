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
MAX_LIST=200
INFLATE_ARCHIVES="false"
STRIP_VERSION="false"
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
    echo "  -f, --format <fmt>       Output format: html, text, smart-html, smart-text, summary (default: html)"
    echo "  -o, --output-dir <dir>   Output directory (default: /output)"
    echo "  -s, --stdout             Print output to stdout as well"
    echo "      --max-list <n>       Max paths listed per section in summary format (default: 200)"
    echo "      --inflate             Decompress archive files before comparison (default: disabled)"
    echo "      --strip-version      Drop version numbers from inflated archive directory names,"
    echo "                           so the same artifact lines up across images (implies --inflate)"
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
    --max-list)
      MAX_LIST="$2"
      shift 2
      ;;
    --inflate)
      INFLATE_ARCHIVES="true"
      shift
      ;;
    --strip-version)
      STRIP_VERSION="true"
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

if [[ "$FORMAT" =~ ^(html|text|smart-html|smart-text|summary)$ ]]; then
    echo "✅ Using format: $FORMAT"
else
    echo "❌ Error: $FORMAT is not a supported format"
    usage
fi

REL_PATH=${PATH_TO_DIFF#/}

# --- Libraries ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/archive_handlers.sh"
source "$SCRIPT_DIR/lib/oci_layers.sh"
source "$SCRIPT_DIR/lib/compare.sh"

# --- OCI Extraction Function ---
extract_oci_fs() {
    local img_name=$1
    local dest=$2
    local work

    echo "🚚 Exporting $img_name..."
    mkdir -p "$dest"

    # The OCI layout is staged outside $dest so that an opaque whiteout at
    # the root of a layer cannot delete it mid-flatten.
    work=$(mktemp -d)

    if ! regctl image export --platform local "$img_name" > "$work/export.tar"; then
        echo "❌ Error: Failed to export $img_name" >&2
        rm -rf "$work"
        exit 1
    fi

    tar -xf "$work/export.tar" -C "$work"

    echo "📂 Flattening OCI layers for $img_name..."
    if ! flatten_oci_layers "$work" "$dest"; then
        rm -rf "$work"
        exit 1
    fi

    rm -rf "$work"
}

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
    local -a ext_array
    IFS=',' read -ra ext_array <<< "$extensions"

    local -a archives=()
    local file
    while IFS= read -r file; do
        if [ -n "$(archive_extension_for "$(basename "$file")" "${ext_array[@]}")" ]; then
            archives+=("$file")
        fi
    done < <(find "$base_dir" -type f)

    if [ "${#archives[@]}" -eq 0 ]; then
        return 0
    fi

    # Two archives in one directory can reduce to the same versionless name.
    # Those keep their versioned directory so their contents never merge.
    local -A stripped_count=()
    local key
    if [ "$STRIP_VERSION" == "true" ]; then
        for file in "${archives[@]}"; do
            key="$(dirname "$file")/$(strip_archive_version "$(basename "$file")")"
            stripped_count["$key"]=$(( ${stripped_count["$key"]:-0} + 1 ))
        done
    fi

    local filename ext inflated_path
    for file in "${archives[@]}"; do
        filename=$(basename "$file")
        ext=$(archive_extension_for "$filename" "${ext_array[@]}")

        if ! has_archive_handler "$ext"; then
            continue
        fi

        inflated_path="${file}_inflated"
        if [ "$STRIP_VERSION" == "true" ]; then
            key="$(dirname "$file")/$(strip_archive_version "$filename")"
            if [ "${stripped_count[$key]}" -eq 1 ]; then
                inflated_path="${key}_inflated"
            fi
        fi

        if [ -d "$inflated_path" ]; then
            continue
        fi

        echo "  📂 Inflating: $filename"
        mkdir -p "$inflated_path"

        if ! execute_archive_handler "$ext" "$file" "$inflated_path" "$filename"; then
            echo "  ❌ Failed to inflate: $filename"
            rm -rf "$inflated_path"
        fi
    done
}

# --- Main Execution ---
# A tree left behind by an earlier run would be merged into this one, so each
# run gets its own workspace.
RUN_DIR=$(mktemp -d)
trap 'rm -rf "$RUN_DIR"' EXIT

mkdir -p "$RUN_DIR/img1" "$RUN_DIR/img2" "$RUN_DIR/work"
extract_oci_fs "$IMAGE1" "$RUN_DIR/img1"
extract_oci_fs "$IMAGE2" "$RUN_DIR/img2"

# Inflate archives if requested
inflate_archives "$RUN_DIR/img1" "$INFLATE_EXTENSIONS"
inflate_archives "$RUN_DIR/img2" "$INFLATE_EXTENSIONS"

DIR1="$RUN_DIR/img1/$REL_PATH"
DIR2="$RUN_DIR/img2/$REL_PATH"

if [ ! -d "$DIR1" ] || [ ! -d "$DIR2" ]; then
    echo "❌ Error: Path /$REL_PATH not found in one or both images."
    exit 1
fi

# Explain why two images with different digests can hold identical files.
metadata_note() {
    local work=$1
    echo "The two images carry the same files. Their digests differ because the"
    echo "layer tarballs were produced by separate builds and therefore record"
    echo "different file modification times."
    if [ -s "$work/meta.diff" ]; then
        echo "Note: mode, ownership or symlink targets differ, see the metadata section."
    fi
}

render_summary() {
    local work=$1
    local added removed changed meta_changes digest1 digest2

    added=$(wc -l < "$work/added")
    removed=$(wc -l < "$work/removed")
    changed=$(wc -l < "$work/changed")
    meta_changes=$(grep -cE '^[+-][^+-]' "$work/meta.diff" || true)

    digest1=$(regctl image digest "$IMAGE1" 2>/dev/null || echo "unavailable")
    digest2=$(regctl image digest "$IMAGE2" 2>/dev/null || echo "unavailable")

    echo "OCI image comparison"
    echo "===================="
    echo
    echo "left  : $IMAGE1"
    echo "        $digest1"
    echo "right : $IMAGE2"
    echo "        $digest2"
    echo "path  : /$REL_PATH"
    if [ "$INFLATE_ARCHIVES" == "true" ]; then
        if [ "$STRIP_VERSION" == "true" ]; then
            echo "note  : archives inflated, versions stripped from their directory names"
        else
            echo "note  : archives inflated before comparison"
        fi
    fi
    echo
    echo "Content"
    echo "  files left / right : $(wc -l < "$work/paths1") / $(wc -l < "$work/paths2")"
    echo "  added              : $added"
    echo "  removed            : $removed"
    echo "  changed            : $changed"

    if [ "$added" -gt 0 ]; then
        echo
        echo "  Added:"
        print_capped_list "$work/added" "$MAX_LIST"
    fi
    if [ "$removed" -gt 0 ]; then
        echo
        echo "  Removed:"
        print_capped_list "$work/removed" "$MAX_LIST"
    fi
    if [ "$changed" -gt 0 ]; then
        echo
        echo "  Changed:"
        print_capped_list "$work/changed" "$MAX_LIST"
    fi

    echo
    echo "Metadata (type, mode, ownership, symlink targets)"
    if [ "$meta_changes" -eq 0 ]; then
        echo "  identical"
    else
        echo "  $meta_changes differing entries"
        echo "$(tail -n +3 "$work/meta.diff" | grep -E '^[+-][^+-]' | head -n "$MAX_LIST" | sed 's/^/    /')"
    fi

    echo
    echo "Image configuration"
    if fetch_image_configs "$IMAGE1" "$IMAGE2" "$work"; then
        config_diff_report "$work"
    else
        echo "  unavailable"
    fi

    echo
    echo "Verdict"
    if [ $(( added + removed + changed )) -eq 0 ]; then
        if [ "$meta_changes" -eq 0 ]; then
            echo "  No differences under /$REL_PATH."
            if [ "$digest1" != "$digest2" ]; then
                echo
                metadata_note "$work" | sed 's/^/  /'
            fi
        else
            echo "  File contents are identical; only metadata differs."
        fi
    else
        echo "  $added added, $removed removed, $changed changed under /$REL_PATH."
    fi
}

# --- Output Logic ---
mkdir -p "$OUT_DIR"
case "$FORMAT" in
    "summary")
        echo "🔍 Building content summary..."
        WORK="$RUN_DIR/work"
        compare_trees "$DIR1" "$DIR2" "$WORK"
        render_summary "$WORK" > "$OUT_DIR/${REPORT_NAME}.txt"
        if [ "$TO_STDOUT" == "true" ]; then
            cat "$OUT_DIR/${REPORT_NAME}.txt"
        fi
        echo "✅ Summary report saved to ${REPORT_NAME}.txt"
        ;;

    "smart-text")
        echo "🔍 Running Difftastic (Structural Text mode)..."
        difft --skip-unchanged --color always "$DIR1" "$DIR2" > "$OUT_DIR/${REPORT_NAME}.txt"
        if [ "$TO_STDOUT" == "true" ]; then
            cat "$OUT_DIR/${REPORT_NAME}.txt"
        fi
        echo "✅ Textual report saved to ${REPORT_NAME}.txt"
        ;;

    "smart-html")
        echo "🔍 Running Difftastic (Structural HTML mode)..."
        # Removed --full and used the standard pipe. 
        # ansi2html (pip version) creates a partial by default, 
        # or we can use the 'man' style or just let it wrap.
        difft --skip-unchanged --color always "$DIR1" "$DIR2" | ansi2html > "$OUT_DIR/${REPORT_NAME}.html"
        
        if [ "$TO_STDOUT" == "true" ]; then
            difft --color always "$DIR1" "$DIR2"
        fi
        echo "✅ Structural HTML report saved to ${REPORT_NAME}.html"
        ;;

    "text")
        echo "🔍 Running Standard Diff (Text mode)..."
        # Generate standard unified diff
        diff -Nru --no-dereference "$DIR1" "$DIR2" > "$OUT_DIR/${REPORT_NAME}.txt" || true
        if [ ! -s "$OUT_DIR/${REPORT_NAME}.txt" ]; then
            echo "🎉 No differences found!"
            WORK="$RUN_DIR/work"
            metadata_manifest "$DIR1" > "$WORK/meta1"
            metadata_manifest "$DIR2" > "$WORK/meta2"
            diff -u "$WORK/meta1" "$WORK/meta2" > "$WORK/meta.diff" || true
            {
                echo "No changes detected at /$REL_PATH"
                echo
                metadata_note "$WORK"
            } > "$OUT_DIR/${REPORT_NAME}.txt"
            cat "$OUT_DIR/${REPORT_NAME}.txt"
        fi
        echo "✅ Textual report saved to ${REPORT_NAME}.txt"
        ;;

    "html")
        echo "🔍 Running Standard Diff (HTML mode)..."
        # Generate standard unified diff
        diff -Nru --no-dereference "$DIR1" "$DIR2" > "$RUN_DIR/combined.diff" || true
        
        if [ ! -s "$RUN_DIR/combined.diff" ]; then
            echo "🎉 No differences found!"
            WORK="$RUN_DIR/work"
            metadata_manifest "$DIR1" > "$WORK/meta1"
            metadata_manifest "$DIR2" > "$WORK/meta2"
            diff -u "$WORK/meta1" "$WORK/meta2" > "$WORK/meta.diff" || true
            {
                echo "<h1>No changes detected at /$REL_PATH</h1>"
                echo "<pre>"
                metadata_note "$WORK"
                echo "</pre>"
            } > "$OUT_DIR/${REPORT_NAME}.html"
            metadata_note "$WORK"
        else
            # Preprocess diff to handle binary files properly
            echo "📝 Preprocessing diff for binary file compatibility..."
            ./preprocess-diff.sh "$RUN_DIR/combined.diff" "$RUN_DIR/processed.diff"
            
            diff2html -i file -s side --summary open \
                --title "Standard Diff: $IMAGE1 vs $IMAGE2" \
                -f html -F "$OUT_DIR/${REPORT_NAME}.html" \
                -- "$RUN_DIR/processed.diff"
            if [ "$TO_STDOUT" == "true" ]; then
                cat "$RUN_DIR/combined.diff"
            fi
            echo "✅ HTML report saved to ${REPORT_NAME}.html"
        fi
        ;;
esac

echo "🏁 Process complete!"