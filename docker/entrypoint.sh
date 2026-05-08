#!/bin/bash
# Entrypoint for the Emcraft Linux-CM build container.
#
#  1. Create an unprivileged user matching the caller's UID/GID so that
#     build outputs written into the bind-mounted release tree are owned
#     by the host user, not root.
#  2. Source ACTIVATE.sh from the bind-mounted release tree (which sets
#     CROSS_COMPILE / PATH / etc. for the toolchain at /work/tools/<sdk>/)
#     and exec the requested command (default: interactive bash).

set -e

USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

if ! getent group "$USER_GID" >/dev/null 2>&1; then
    groupadd -g "$USER_GID" builder
fi
BUILDER_GROUP="$(getent group "$USER_GID" | cut -d: -f1)"

if ! getent passwd "$USER_UID" >/dev/null 2>&1; then
    useradd -m -u "$USER_UID" -g "$USER_GID" -s /bin/bash builder
fi
BUILDER_USER="$(getent passwd "$USER_UID" | cut -d: -f1)"

# Resolve where the BSP tree is mounted. run.sh bind-mounts $ROOT both at
# /work (legacy / customer convention) and at the host path itself
# (BSP_HOST_ROOT, set in env), so INSTALL_ROOT matches between host and
# container and buildroot's local.mk doesn't churn on env switches.
# Fall back to /work for direct `docker run -v $(pwd):/work` invocations.
ACTIVATE_DIR="${BSP_HOST_ROOT:-/work}"
if [ ! -f "$ACTIVATE_DIR/ACTIVATE.sh" ]; then
    cat >&2 <<EOF
ERROR: $ACTIVATE_DIR does not contain ACTIVATE.sh.

Mount the extracted release tree at /work, for example:
  docker run --rm -it -v "\$(pwd):/work" <image>

Or use the docker/run.sh wrapper from inside the release tree.
EOF
    exit 1
fi

export HOME="/home/${BUILDER_USER}"

# The kernel banner ("Linux version X.Y (USER@HOST)") is stamped from
# $KBUILD_BUILD_USER / $KBUILD_BUILD_HOST (scripts/mkcompile_h); without them
# every container build leaks "ubuntu@<container-id>" into dmesg. Defaults are
# computed below, INSIDE the user shell, because they depend on $MCU
# (set by ACTIVATE.sh) and on /work/_MANIFEST (available only after the
# release tree is bind-mounted). The caller can preempt the defaults by
# passing KBUILD_BUILD_USER / KBUILD_BUILD_HOST via `docker run -e ...` or
# directly on the make command line.
exec sudo -u "$BUILDER_USER" -g "$BUILDER_GROUP" \
     --preserve-env=HOME,TERM,KBUILD_BUILD_USER,KBUILD_BUILD_HOST,MCU,BUILDROOT_DEFCONFIG,BSP_HOST_ROOT \
     bash -c '
        cd "${BSP_HOST_ROOT:-/work}" || exit 1
        # Stash the user command before sourcing ACTIVATE.sh: bash -c "...
        # exec \"$@\"" forwards the user command into $@, and ACTIVATE.sh
        # reads $1 as the MCU selector, so an unstashed call would feed e.g.
        # "bash" as the MCU and fail validation.
        _saved=("$@")
        set --
        # shellcheck disable=SC1091
        source ./ACTIVATE.sh ${MCU:+"$MCU"} ${BUILDROOT_DEFCONFIG:+"$BUILDROOT_DEFCONFIG"} >/dev/null || exit 1
        set -- "${_saved[@]}"
        unset _saved

        # Default banner format: "<mcu-lowercased-with-dashes>@linux-cm[-<ver>]"
        # e.g. "imxrt117x-nxpevk@linux-cm-3.3.1". MCU comes from ACTIVATE.sh.
        if [ -z "${KBUILD_BUILD_USER:-}" ] && [ -n "${MCU:-}" ]; then
            KBUILD_BUILD_USER="$(printf %s "${MCU,,}" | tr _ -)"
        fi
        release_version=""
        if [ -f /work/tools/docker/_release_version.sh ]; then
            . /work/tools/docker/_release_version.sh
            release_version=$(release_version_from_manifest /work/_MANIFEST)
        fi
        if [ -z "${KBUILD_BUILD_HOST:-}" ]; then
            KBUILD_BUILD_HOST="linux-cm${release_version:+-${release_version}}"
        fi
        export KBUILD_BUILD_USER KBUILD_BUILD_HOST

        # Welcome banner -- only when launching an interactive shell with a
        # tty. Stays out of the way of "run.sh make ...", scripts, and CI.
        if [ -t 1 ] && [ "$#" -eq 1 ] && [ "$(basename -- "$1")" = "bash" ]; then
            G="\e[1;32m"; R="\e[0m"
            printf "\n${G}================================================================${R}\n"
            printf "${G} Emcraft Linux-CM build environment${R}\n"
            printf "   Target:  %s\n" "${MCU:-(not set)}"
            printf "   SDK:     %s\n" "${BUILDROOT_DEFCONFIG:-tools/ (legacy)}"
            printf "   Release: %s\n" "${release_version:-unknown}"
            printf "\n Build kernel + rootfs (cd to a project, e.g. projects/rootfs):\n"
            printf "   make                       full build (kernel + apps + initramfs)\n"
            printf "   make kmenuconfig           interactive kernel configuration\n"
            printf "   make bmenuconfig           interactive BusyBox configuration\n"
            printf "   make buildroot-menuconfig  interactive Buildroot configuration\n"
            printf "\n Build U-Boot (cd u-boot/; see u-boot/configs/ for defconfigs):\n"
            printf "   make <board>_defconfig     pick a config from u-boot/configs/\n"
            printf "   make                       build U-Boot\n"
            printf "\n Flash the board (i.MX RT family, USB attached in ROM mode):\n"
            printf "   imxrt_install.sh -a\n"
            printf "\n Type %sexit%s to leave the container.\n" "\`" "\`"
            printf "${G}================================================================${R}\n\n"
        fi

        exec "$@"
     ' -- "$@"
