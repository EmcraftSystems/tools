TOOLCHAIN=arm-v7-linux-uclibceabi
export INSTALL_ROOT=`pwd`
TOOLS_PATH=$INSTALL_ROOT/tools
CROSS_PATH=$TOOLS_PATH/$TOOLCHAIN/bin
export PATH=$TOOLS_PATH/bin:$CROSS_PATH:$PATH

export CROSS_COMPILE=arm-v7-linux-uclibceabi-
export CROSS_COMPILE_APPS=arm-v7-linux-uclibceabi-

export ARCH=arm
export MCU=LPC

