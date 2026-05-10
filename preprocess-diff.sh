#!/bin/bash
set -e

# Preprocess diff file to convert binary file differences into diff2html-compatible format
# This converts "Binary files X and Y differ" lines into proper diff format

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <input_diff_file> <output_diff_file>"
    exit 1
fi

# Create a temporary file for processing
TEMP_FILE=$(mktemp)

# Process the diff file:
# 1. Convert "Binary files X and Y differ" to proper diff format
# 2. Keep all other diff content unchanged

awk '
/^Binary files .* and .* differ$/ {
    # Extract file paths using gsub to remove the prefix and suffix
    line = $0
    gsub(/^Binary files /, "", line)
    gsub(/ and .* differ$/, "", line)
    file1 = line
    
    # Extract second file path
    line = $0
    gsub(/^Binary files .* and /, "", line)
    gsub(/ differ$/, "", line)
    file2 = line
    
    # Generate a proper diff format for binary files
    print "--- " file1
    print "+++ " file2
    print "@@ -1,1 +1,1 @@"
    print "-Binary file (content differs)"
    print "+Binary file (content differs)"
    print ""
    
    next
}

{
    # Print all other lines as-is
    print
}
' "$INPUT_FILE" > "$TEMP_FILE"

# Move the processed file to the output location
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Preprocessed diff file saved to: $OUTPUT_FILE"
