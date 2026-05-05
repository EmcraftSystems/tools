#!/bin/sh
# _MANIFEST format (single line): linux-cm-<product>-<N.N.N>-<MCU>[...]
# Strip the trailing -<MCU> token (recognised by its all-caps shape) and
# take the last N.N.N from what remains. Survives a future manifest format
# bump that mentions a kernel/U-Boot version triple earlier in the line.
release_version_from_manifest() {
    [ -f "$1" ] || return 0
    head -1 "$1" \
        | sed -E 's/-[A-Z][A-Z0-9_]*$//' \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
        | tail -1
}
