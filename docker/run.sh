#!/bin/bash
# Customer-facing wrapper: runs a command (or an interactive shell) inside
# the Emcraft build container, with the release tree bind-mounted at /work
# and the caller's UID/GID preserved.
#
# Usage from anywhere inside the release tree:
#   ./tools/docker/run.sh                              # interactive shell
#   ./tools/docker/run.sh make                         # build the current directory
#   ./tools/docker/run.sh make -C projects/rootfs
#   ./tools/docker/run.sh --mcu MAAXBOARD_RT make      # one-shot target override
#   MCU=MAAXBOARD_RT ./tools/docker/run.sh make        # same via env var
#
# Flags (must precede the command; use `--` to end flag parsing explicitly):
#   -m, --mcu MCU    Select MCU target. Validated by ACTIVATE.sh inside the
#                    container; overrides any inherited $MCU.
#   --build          Force a rebuild of the image and exit; do not run
#                    any command.
#
# Env vars:
#   NO_AUTO_BUILD    Don't auto-build the image (neither when missing
#                    nor when stale); error out instead.
#   WITH_INSTALLER   Use the with-installer image variant and pass USB/HID
#                    through so imxrt_install.sh works inside the container.
#                    Requires the image to have been built with the same
#                    flag set.

set -e

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname -- "$(dirname -- "$HERE")")"

if [ ! -f "$ROOT/ACTIVATE.sh" ]; then
    echo "ERROR: $ROOT does not look like an Emcraft Linux-CM release tree" >&2
    echo "       (no ACTIVATE.sh found two levels above this script)." >&2
    exit 1
fi

BUILD_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        -m|--mcu)
            [ $# -ge 2 ] || { echo "ERROR: $1 requires an argument" >&2; exit 1; }
            MCU="$2"
            shift 2
            ;;
        --mcu=*)
            MCU="${1#--mcu=}"
            shift
            ;;
        --build)
            BUILD_ONLY=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

. "$HERE/_release_version.sh"
release_version=$(release_version_from_manifest "$ROOT/_MANIFEST")
WITH_INSTALLER="${WITH_INSTALLER:-0}"
suffix=""
[ "$WITH_INSTALLER" = "1" ] && suffix="-installer"
IMAGE="emcraft/linux-cm-build${release_version:+:$release_version}${suffix}"

build_image() {
    echo "Building image: $IMAGE" >&2
    (cd "$HERE" && docker build --build-arg WITH_INSTALLER="$WITH_INSTALLER" -t "$IMAGE" .)
    # Sidecar marker: written on every successful build so we can detect
    # stale inputs later. We can't use the image's Created timestamp because
    # a no-op rebuild (all layers cached) keeps the same SHA + Created.
    touch "$HERE/.image-built-at"
}

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed or not in PATH." >&2
    exit 1
fi

if [ "$BUILD_ONLY" = "1" ]; then
    build_image
    exit 0
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    if [ -n "${NO_AUTO_BUILD:-}" ]; then
        cat >&2 <<EOF
ERROR: Docker image '$IMAGE' is not present on this host
       (NO_AUTO_BUILD is set, so it won't be built automatically).

Build it once with:
  $0 --build

See $HERE/README.md for details.
EOF
        exit 1
    fi
    echo "Image '$IMAGE' not present; building it (first build can take a few minutes; subsequent builds are usually cached)..." >&2
    build_image
fi

# Auto-rebuild if Dockerfile or entrypoint.sh is newer than the last completed
# build. Set NO_AUTO_BUILD=1 to opt out (mtimes can lie after `git checkout`
# or `cp` without -p).
if [ -z "${NO_AUTO_BUILD:-}" ]; then
    marker="$HERE/.image-built-at"
    if [ ! -f "$marker" ]; then
        image_epoch=$(date -d "$(docker image inspect "$IMAGE" --format '{{.Created}}')" +%s 2>/dev/null || echo 0)
        if [ "$image_epoch" -gt 0 ]; then
            touch -d "@$image_epoch" "$marker" 2>/dev/null || marker=""
        else
            marker=""
        fi
    fi

    if [ -n "$marker" ]; then
        newer=$(find "$HERE/Dockerfile" "$HERE/entrypoint.sh" -newer "$marker" -type f -print 2>/dev/null | head -1)
        if [ -n "$newer" ]; then
            echo "Image '$IMAGE' is older than ${newer#$ROOT/}; rebuilding..." >&2
            build_image
        fi
    fi
fi

# Preserve the caller's working directory inside the container so that
# "cd projects/rootfs && ../../docker/run.sh make" behaves as expected.
RELPATH="$(realpath --relative-to="$ROOT" "$PWD" 2>/dev/null || echo .)"
if [ "$RELPATH" = "." ]; then
    WORKDIR="/work"
else
    WORKDIR="/work/$RELPATH"
fi

TTY_ARGS=()
if [ -t 0 ] && [ -t 1 ]; then
    TTY_ARGS+=(-it)
fi

# USB / HID passthrough for blhost / sdphost / imxrt_install.sh. Only
# applied when WITH_INSTALLER=1 (the same flag that selects the installer
# image variant) and the host has /dev/bus/usb (Linux). On
# macOS / Windows / WSL2 the host has no /dev/bus/usb so this is a no-op
# and flashing has to be arranged outside the container.
#
# We bind-mount the host /dev (not just /dev/bus/usb) because the i.MX RT
# install flow re-enumerates the chip mid-flash: ROM-mode hidraw goes away,
# flashloader-mode hidraw appears with a new node number. A static --device
# snapshot at container-start misses the second one. Bind-mounting /dev
# means new device nodes appear inside the container live.
#
# Two cgroup rules grant access at the kernel level:
#   - USB raw transport (major 189)
#   - HID raw character devices (major is allocated dynamically; we read it
#     from /proc/devices)
USB_ARGS=()
if [ "$WITH_INSTALLER" = "1" ] && [ -d /dev/bus/usb ]; then
    USB_ARGS+=(-v /dev:/dev)
    USB_ARGS+=(--device-cgroup-rule='c 189:* rmw')

    HIDRAW_MAJOR="$(awk '$2 == "hidraw" {print $1}' /proc/devices 2>/dev/null)"
    if [ -n "$HIDRAW_MAJOR" ]; then
        USB_ARGS+=(--device-cgroup-rule="c ${HIDRAW_MAJOR}:* rmw")
    fi
fi

ENV_ARGS=()
if [ -n "${MCU:-}" ]; then
    ENV_ARGS+=(-e "MCU=$MCU")
fi

# If any tools/ entry is a symlink pointing outside the release tree (e.g.
# tools/<sdk> -> /usr/local/<sdk> in a dev setup), the /work bind mount
# alone leaves the symlink dangling inside the container. Bind-mount each
# such target at the same absolute path so the symlink resolves
# identically inside vs outside.
SYMLINK_MOUNTS=()
if [ -d "$ROOT/tools" ]; then
    for entry in "$ROOT/tools"/*; do
        [ -L "$entry" ] || continue
        target=$(readlink -f "$entry") || continue
        [ -e "$target" ] || continue
        case "$target" in
            "$ROOT"/*) continue ;;
        esac
        SYMLINK_MOUNTS+=(-v "$target:$target")
    done
fi

exec docker run --rm "${TTY_ARGS[@]}" \
    -v "$ROOT:/work" \
    "${SYMLINK_MOUNTS[@]}" \
    "${USB_ARGS[@]}" \
    -e USER_UID="$(id -u)" \
    -e USER_GID="$(id -g)" \
    "${ENV_ARGS[@]}" \
    -w "$WORKDIR" \
    "$IMAGE" \
    "$@"
