# oci-img-diff
`oci-img-diff` is a CLI tool that allows you to compare the contents of two OCI images.
It generates a report that highlights the differences between the flattened layers of the two images, making it easier to understand what has changed between them.
If you need a layer-aware comparison instead, check [diffoci](https://github.com/reproducible-containers/diffoci)

# Features
This tool allows you to compare two OCI images and generate a report of the differences between them. The report can be saved to a file or printed to stdout.

- Supports both Docker and Registries
- Supports multiple output formats: HTML, Text, Smart-HTML, Smart-Text
- Supports printing the output to stdout as well as saving it to a file
- Supports specifying a specific path within the image to compare
- Supports both standard diff and difftastic structural diff
- Supports both OCI and Docker images
- **Archive Inflation**: Automatically decompresses archive files before comparison for deeper analysis
- **Plugin System**: Extensible support for custom archive formats via plugins

To use the tool, you need to pass in the two images you want to compare, as well as the output format and optional path to diff. For example:

```
docker run --rm \
  -v /tmp/ \
  -v /path/to/output:/output \
  ghcr.io/davidecavestro/oci-img-diff:latest \
  --left image1:tag \
  --right image2:tag \
  --path /path/to/diff \
  --format html
```

This will compare the contents of `image1:tag` and `image2:tag` at the `/path/to/diff` directory, and save the output to `/path/to/output/diff_report.html`.

You can also specify other output formats such as `text`, `smart-html`, and `smart-text`.

## Archive Inflation

The tool supports automatic decompression of archive files to enable deeper comparison of container contents. Use the `--inflate` flag to enable:

```bash
docker run --rm \
  ghcr.io/davidecavestro/oci-img-diff:latest \
  --left image1:tag \
  --right image2:tag \
  --inflate \
  --format text
```

### Supported Archive Formats
By default, the following archive formats are supported:
- `.jar`, `.war`, `.ear`, `.zip` - Java archives and ZIP files
- `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tar.xz` - Tape archives
- `.gz`, `.bz2`, `.xz` - Compressed files
- `.deb`, `.rpm` - Package files

### Custom Archive Support

The tool features a modular plugin system that allows adding support for additional archive formats. To add custom archive support:

1. **Create a plugin file** in the `plugins/` directory
2. **Register handlers** using the `register_archive_handler` function:

```bash
#!/usr/bin/env bash
# Example: Add support for .7z files
if command -v 7z >/dev/null 2>&1; then
    register_archive_handler ".7z" "7z x \"\$file\" -o\"\$inflated_path\" 2>/dev/null"
fi
```

3. **Place plugin in `plugins/` directory** - it will be automatically loaded

The plugin system provides the following functions:
- `register_archive_handler <extension> <command>` - Register a new archive handler
- `has_archive_handler <extension>` - Check if handler exists
- `get_archive_handler <extension>` - Get handler command
- `list_archive_handlers` - List all registered handlers

### Example Plugin
See `plugins/custom_archive.sh` for an example plugin that adds support for:
- `.7z` - 7-Zip archives
- `.rar` - RAR archives
- `.lha` - LHA archives
- `.iso` - ISO images (mount and copy)

This extensible architecture allows the tool to support virtually any archive format while maintaining backward compatibility with existing functionality.