#!/usr/bin/env bash

# Flattening of OCI image layers into a single root filesystem.

# Apply a single layer tarball on top of an already accumulated tree.
#
# Deletions are encoded in the layer as whiteout markers rather than as
# absent files, so they must be resolved against the lower layers before
# the layer payload is unpacked:
#   <dir>/.wh.<name>      removes <dir>/<name>
#   <dir>/.wh..wh..opq    removes every entry <dir> inherited from below
apply_layer() {
    local layer_tar=$1
    local dest=$2
    local entry base dir target

    while IFS= read -r entry; do
        entry=${entry#./}
        [ -n "$entry" ] || continue
        base=${entry##*/}
        dir=${entry%"$base"}

        case "$base" in
            .wh..wh..opq)
                target="$dest/${dir%/}"
                if [ -d "$target" ]; then
                    find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
                fi
                ;;
            .wh.*)
                target="$dest/${dir}${base#.wh.}"
                rm -rf "$target"
                ;;
        esac
    done < <(tar -tf "$layer_tar")

    local tar_err status=0
    tar_err=$(tar -xf "$layer_tar" -C "$dest" \
        --overwrite \
        --delay-directory-restore \
        --exclude='.wh.*' 2>&1) || status=$?

    # tar reports recoverable conditions with status 1; only higher is fatal.
    if [ "$status" -gt 1 ]; then
        echo "❌ Error: failed to unpack layer $layer_tar" >&2
        echo "$tar_err" >&2
        echo "   Unpacking image layers faithfully requires root." >&2
        return 1
    fi

    return 0
}

# Unpack every layer of an extracted OCI layout into a single tree.
flatten_oci_layers() {
    local oci_dir=$1
    local dest=$2
    local manifest layer_path
    local -a layer_paths

    if [ ! -f "$oci_dir/index.json" ]; then
        echo "❌ Error: no index.json in OCI layout $oci_dir" >&2
        return 1
    fi

    manifest=$(jq -r '.manifests[0].digest | sub("sha256:"; "blobs/sha256/")' "$oci_dir/index.json")
    if [ -z "$manifest" ] || [ ! -f "$oci_dir/$manifest" ]; then
        echo "❌ Error: manifest blob not found in $oci_dir" >&2
        return 1
    fi

    mapfile -t layer_paths < <(jq -r '.layers[].digest | sub("sha256:"; "blobs/sha256/")' "$oci_dir/$manifest")

    for layer_path in "${layer_paths[@]}"; do
        if [ ! -f "$oci_dir/$layer_path" ]; then
            echo "❌ Error: missing layer blob $layer_path" >&2
            return 1
        fi
        apply_layer "$oci_dir/$layer_path" "$dest" || return 1
    done

    return 0
}
