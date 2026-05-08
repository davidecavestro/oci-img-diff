# oci-img-diff
`oci-img-diff` is a CLI tool that allows you to compare the contents of two OCI images. It generates a report that highlights the differences between the two images, making it easier to understand what has changed between them.

# Features
This tool allows you to compare two OCI images and generate a report of the differences between them. The report can be saved to a file or printed to stdout.

- Supports both Docker and Registries
- Supports multiple output formats: HTML, Text, Smart-HTML, Smart-Text
- Supports printing the output to stdout as well as saving it to a file
- Supports specifying a specific path within the image to compare
- Supports both standard diff and difftastic structural diff
- Supports both OCI and Docker images

To use the tool, you need to pass in the two images you want to compare, as well as the output format and optional path to diff. For example:

```
docker run --rm -v /path/to/output:/output ghcr.io/username/oci-img-diff:latest --left image1:tag --right image2:tag --path /path/to/diff --format html
```

This will compare the contents of `image1:tag` and `image2:tag` at the `/path/to/diff` directory, and save the output to `/path/to/output/diff_report.html`. You can also specify other output formats such as `text`, `smart-html`, and `smart-text`.