TOOLCHAIN=arm-2010q1
export INSTALL_ROOT=`pwd`
TOOLS_PATH=$INSTALL_ROOT/tools
CROSS_PATH=$TOOLS_PATH/$TOOLCHAIN/bin
ARMV7_CROSS_PATH=$TOOLS_PATH/arm-v7-linux-uclibceabi/bin
export PATH=$TOOLS_PATH/bin:$CROSS_PATH:$ARMV7_CROSS_PATH:$PATH

# Path to cross-tools
export CROSS_COMPILE=arm-uclinuxeabi-
export CROSS_COMPILE_APPS=arm-uclinuxeabi-

# Define the MCU architecture
export MCU=K70

