#!/usr/bin/env bash

# Content and metadata comparison of two extracted trees.

# List every regular file as "<sha256>\t<relative path>".
content_manifest() {
    local dir=$1
    ( cd "$dir" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum ) \
        | sed 's/^\([0-9a-f]\{64\}\)  /\1\t/'
}

# List every entry as "<relative path>\t<type> <mode> <owner> -> <symlink target>".
# Mtimes are deliberately excluded: they change on every rebuild and say
# nothing about what the image actually contains.
metadata_manifest() {
    local dir=$1
    ( cd "$dir" && find . -mindepth 1 -printf '%p\t%y %M %U:%G -> %l\n' ) | LC_ALL=C sort
}

# Compare two trees, writing the result files into $work:
#   added, removed, changed  one path per line
#   meta.diff                metadata differences
compare_trees() {
    local dir1=$1
    local dir2=$2
    local work=$3

    content_manifest "$dir1" > "$work/content1"
    content_manifest "$dir2" > "$work/content2"

    cut -f2 "$work/content1" | LC_ALL=C sort > "$work/paths1"
    cut -f2 "$work/content2" | LC_ALL=C sort > "$work/paths2"

    comm -13 "$work/paths1" "$work/paths2" > "$work/added"
    comm -23 "$work/paths1" "$work/paths2" > "$work/removed"

    join -t $'\t' -j 2 -o 0,1.1,2.1 \
        <(LC_ALL=C sort -t $'\t' -k2 "$work/content1") \
        <(LC_ALL=C sort -t $'\t' -k2 "$work/content2") \
        | awk -F '\t' '$2 != $3 { print $1 }' > "$work/changed"

    metadata_manifest "$dir1" > "$work/meta1"
    metadata_manifest "$dir2" > "$work/meta2"
    diff -u "$work/meta1" "$work/meta2" > "$work/meta.diff" || true
}

# Fetch both image configs. Returns non-zero if either is unavailable.
fetch_image_configs() {
    local img1=$1
    local img2=$2
    local work=$3

    regctl image config "$img1" > "$work/config1.json" 2>"$work/config.err" || return 1
    regctl image config "$img2" > "$work/config2.json" 2>"$work/config.err" || return 1
    return 0
}

# Print the runtime configuration differences, ignoring the build timestamp.
config_diff_report() {
    local work=$1
    local created1 created2 body

    created1=$(jq -r '.created // "unknown"' "$work/config1.json")
    created2=$(jq -r '.created // "unknown"' "$work/config2.json")

    echo "  created: $created1"
    echo "        -> $created2"

    body=$(diff -u --label left --label right \
        <(jq -S 'del(.history, .rootfs, .created)' "$work/config1.json") \
        <(jq -S 'del(.history, .rootfs, .created)' "$work/config2.json") || true)

    if [ -z "$body" ]; then
        echo "  runtime config (env, cmd, entrypoint, labels): identical"
    else
        echo "  runtime config differs:"
        echo "$body" | sed 's/^/    /'
    fi

    body=$(diff -u --label left --label right \
        <(jq -r '.history[]?.created_by' "$work/config1.json") \
        <(jq -r '.history[]?.created_by' "$work/config2.json") || true)

    if [ -z "$body" ]; then
        echo "  build history: identical"
    else
        echo "  build history differs:"
        echo "$body" | sed 's/^/    /'
    fi
}

# Print up to $max entries of a list file, noting anything truncated.
print_capped_list() {
    local file=$1
    local max=$2
    local total shown

    total=$(wc -l < "$file")
    [ "$total" -gt 0 ] || return 0

    head -n "$max" "$file" | sed 's/^/    /'
    shown=$(( total < max ? total : max ))
    if [ "$total" -gt "$shown" ]; then
        echo "    ... and $(( total - shown )) more"
    fi
}
