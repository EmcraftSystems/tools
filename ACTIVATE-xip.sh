# Source this script to set up the cross-compilation environment.
#
# Usage:
#   source ACTIVATE.sh                                # use saved selection from .activate-defaults, or built-in default
#   source ACTIVATE.sh <MCU>                          # MCU only; legacy prebuilt toolchain from tools/
#   source ACTIVATE.sh <MCU> <buildroot_defconfig>    # MCU + buildroot-built SDK from buildroot/output_<defconfig>/
#
# The resolved selection is persisted to .activate-defaults at the BSP root;
# subsequent no-arg invocations reproduce it. Explicit args fully replace
# the persisted selection.

export INSTALL_ROOT=`pwd`

_DEFAULT_MCU="STM32H7"
_DEFAULTS_FILE="$INSTALL_ROOT/.activate-defaults"

_SUPPORTED_MCUS="\
IMXRT102X_NXPEVK \
IMXRT105X_NXPEVK \
IMXRT106X_NXPEVK \
IMXRT117X_NXPEVK \
MAAXBOARD_RT \
STM32H7"

_REQUESTED_MCU="$1"
_REQUESTED_DEFCONFIG="$2"

if [ -z "$_REQUESTED_MCU" ] && [ -z "$_REQUESTED_DEFCONFIG" ] && [ -f "$_DEFAULTS_FILE" ]; then
    while IFS='=' read -r _k _v; do
        case "$_k" in
            MCU)                 _REQUESTED_MCU="$_v" ;;
            BUILDROOT_DEFCONFIG) _REQUESTED_DEFCONFIG="$_v" ;;
        esac
    done < "$_DEFAULTS_FILE"
    unset _k _v
fi

_REQUESTED_MCU="${_REQUESTED_MCU:-$_DEFAULT_MCU}"

case " $_SUPPORTED_MCUS " in
    *" $_REQUESTED_MCU "*)
        ;;
    *)
        echo "ACTIVATE.sh: unknown MCU target '$_REQUESTED_MCU'" >&2
        echo "Supported targets:" >&2
        for _m in $_SUPPORTED_MCUS; do
            printf '  %s\n' "$_m" >&2
        done
        unset _SUPPORTED_MCUS _REQUESTED_MCU _REQUESTED_DEFCONFIG _m _DEFAULTS_FILE _DEFAULT_MCU
        return 1 2>/dev/null || exit 1
        ;;
esac

TOOLS_PATH=${TOOLS_PATH:-$INSTALL_ROOT/tools}


if [ -n "$_REQUESTED_DEFCONFIG" ]; then
    if [ ! -f "$INSTALL_ROOT/buildroot/configs/$_REQUESTED_DEFCONFIG" ]; then
        echo "ACTIVATE.sh: unknown buildroot defconfig '$_REQUESTED_DEFCONFIG'" >&2
        echo "Available defconfigs:" >&2
        for _f in "$INSTALL_ROOT/buildroot/configs/"*_defconfig; do
            [ -e "$_f" ] && printf '  %s\n' "$(basename "$_f")" >&2
        done
        unset _SUPPORTED_MCUS _REQUESTED_MCU _REQUESTED_DEFCONFIG _m _f _DEFAULTS_FILE _DEFAULT_MCU TOOLS_PATH
        return 1 2>/dev/null || exit 1
    fi
fi

export ARCH=arm
export MCU="$_REQUESTED_MCU"

{
    echo "MCU=$_REQUESTED_MCU"
    [ -n "$_REQUESTED_DEFCONFIG" ] && echo "BUILDROOT_DEFCONFIG=$_REQUESTED_DEFCONFIG"
} > "$_DEFAULTS_FILE"

# Single toolchain (buildroot-built FDPIC GCC) drives kernel, U-Boot, and
# userspace apps. Bare-metal targets need -mno-fdpic -fno-pic -no-pie in
# their CFLAGS to suppress this gcc's FDPIC/PIE defaults; the kernel and
# U-Boot armv7m configs already add these.
CROSS_COMPILE_APPS_NAME=arm-buildroot-uclinuxfdpiceabi
export CROSS_COMPILE=${CROSS_COMPILE_APPS_NAME}-
export CROSS_COMPILE_APPS=${CROSS_COMPILE_APPS_NAME}-

if [ -n "$_REQUESTED_DEFCONFIG" ]; then
    export BUILDROOT_DEFCONFIG="$_REQUESTED_DEFCONFIG"
    _BR_OUT_NAME="output_${BUILDROOT_DEFCONFIG%_defconfig}"
    export BUILDROOT_OUTPUT="$INSTALL_ROOT/buildroot/$_BR_OUT_NAME"
    export PATH="$BUILDROOT_OUTPUT/host/bin:$PATH"
    export TOOLS_DIR="$BUILDROOT_OUTPUT/host/$CROSS_COMPILE_APPS_NAME"
    export TOOLS_LIBS="$BUILDROOT_OUTPUT/host/$CROSS_COMPILE_APPS_NAME/sysroot"
    echo "ACTIVATE.sh: MCU=$MCU  buildroot SDK=$BUILDROOT_DEFCONFIG"
    unset _BR_OUT_NAME
else
    TOOLCHAIN_APPS=arm-buildroot-uclinuxfdpiceabi_sdk-buildroot
    export PATH="$TOOLS_PATH/$TOOLCHAIN_APPS/bin:$PATH"
    export TOOLS_DIR="$TOOLS_PATH/$TOOLCHAIN_APPS/$CROSS_COMPILE_APPS_NAME"
    export TOOLS_LIBS="$TOOLS_DIR/sysroot"
    unset BUILDROOT_DEFCONFIG BUILDROOT_OUTPUT
    echo "ACTIVATE.sh: MCU=$MCU  toolchain=tools/ (legacy)"
    unset TOOLCHAIN_APPS
fi

export PATH=$TOOLS_PATH/bin:$PATH

unset _SUPPORTED_MCUS _REQUESTED_MCU _REQUESTED_DEFCONFIG _m _f _DEFAULTS_FILE _DEFAULT_MCU CROSS_COMPILE_APPS_NAME TOOLS_PATH
