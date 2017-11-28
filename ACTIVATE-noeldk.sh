export YOCTO_ROOT=/opt/poky/1.8.1
export IPK_REPO=$YOCTO_ROOT/packages

export INSTALL_ROOT=`pwd`

export MQX_TOOLCHAIN_DIR=/usr/local/gcc-arm-none-eabi-4_8-2014q1
export TOOLCHAIN_ROOTDIR=$MQX_TOOLCHAIN_DIR
export HOST_PYTHON_EXE_PATH=/usr/bin/python

# Define the MCU architecture
# export MCU=VF6

source $YOCTO_ROOT/environment-setup-cortexa5hf-vfp-neon-poky-linux-gnueabi
unset PYTHONHOME
unset CCACHE_PATH

export CXXFLAGS="$CXXFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export LDFLAGS="$LDFLAGS -L$INSTALL_ROOT/target/root/usr/lib"
export CFLAGS="$CFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export CPPFLAGS="$CPPLAGS -I$INSTALL_ROOT/target/root/usr/include"
