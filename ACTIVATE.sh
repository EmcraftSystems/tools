TOOLCHAIN=arm-2010q1
export INSTALL_ROOT=`pwd`
TOOLS_PATH=$INSTALL_ROOT/tools
CROSS_PATH=$TOOLS_PATH/$TOOLCHAIN/bin
export PATH=$CROSS_PATH:$TOOLS_PATH/bin:$PATH

# For kernel and U-Boot build:
export CROSS_COMPILE=arm-none-eabi-

# For the user-space applications build:
export CROSS_COMPILE_APPS=arm-uclinuxeabi-

# Define the MCU architecture
export MCU=A2F

