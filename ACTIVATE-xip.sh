export ARCH=arm
export MCU=STM32H7

export INSTALL_ROOT=`pwd`
TOOLS_PATH=$INSTALL_ROOT/tools

TOOLCHAIN=gcc-arm-none-eabi-10.3-2021.10
export CROSS_COMPILE=arm-none-eabi-
export PATH=$TOOLS_PATH/$TOOLCHAIN/bin:$PATH

TOOLCHAIN_APPS=arm-v7-linux-uclibceabi
export CROSS_COMPILE_APPS=arm-v7-linux-uclibceabi-
export PATH=$TOOLS_PATH/$TOOLCHAIN_APPS/bin:$PATH

export PATH=$TOOLS_PATH/bin:$PATH
