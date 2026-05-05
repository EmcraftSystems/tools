# Source this script to set up the cross-compilation environment.
#
# Usage:
#   source ACTIVATE.sh                       # default: STM32H7
#   source ACTIVATE.sh <MCU>                 # pick a target

# Hard-coded list of supported MCU targets. Keep in sync with the per-MCU
# defconfigs / device-tree files under projects/.
_SUPPORTED_MCUS="\
IMXRT102X_NXPEVK \
IMXRT105X_NXPEVK \
IMXRT106X_NXPEVK \
IMXRT117X_NXPEVK \
MAAXBOARD_RT \
STM32H7"

_REQUESTED_MCU="${1:-STM32H7}"

case " $_SUPPORTED_MCUS " in
    *" $_REQUESTED_MCU "*)
        ;;
    *)
        echo "ACTIVATE.sh: unknown MCU target '$_REQUESTED_MCU'" >&2
        echo "Supported targets:" >&2
        for _m in $_SUPPORTED_MCUS; do
            printf '  %s\n' "$_m" >&2
        done
        unset _SUPPORTED_MCUS _REQUESTED_MCU _m
        return 1 2>/dev/null || exit 1
        ;;
esac

export ARCH=arm
export MCU="$_REQUESTED_MCU"
unset _SUPPORTED_MCUS _REQUESTED_MCU

export INSTALL_ROOT=`pwd`
TOOLS_PATH=${TOOLS_PATH:-$INSTALL_ROOT/tools}

# Single toolchain (buildroot-built FDPIC GCC) drives kernel, U-Boot, and
# userspace apps.
TOOLCHAIN_APPS=arm-buildroot-uclinuxfdpiceabi_sdk-buildroot
CROSS_COMPILE_APPS_NAME=arm-buildroot-uclinuxfdpiceabi
export CROSS_COMPILE=${CROSS_COMPILE_APPS_NAME}-
export CROSS_COMPILE_APPS=${CROSS_COMPILE_APPS_NAME}-
export PATH=$TOOLS_PATH/$TOOLCHAIN_APPS/bin:$PATH

export TOOLS_DIR=$TOOLS_PATH/$TOOLCHAIN_APPS/$CROSS_COMPILE_APPS_NAME
export TOOLS_LIBS=$TOOLS_DIR/sysroot

export PATH=$TOOLS_PATH/bin:$PATH
