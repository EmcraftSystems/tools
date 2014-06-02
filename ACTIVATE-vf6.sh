export INSTALL_ROOT=`pwd`
export ELDK_ROOTFS=/opt/eldk-5.3-vybrid/armv7a/rootfs-java-qte-sdk
export MQX_TOOLCHAIN_DIR=/usr/local/arm-2012
export HOST_PYTHON_EXE_PATH=/usr/bin/python

# Define the MCU architecture
export MCU=VF6

eval `eldk-switch.sh -r 5.3-vybrid armv7a`

export CXXFLAGS="$CXXFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export LDFLAGS="$LDFLAGS -L$INSTALL_ROOT/target/root/usr/lib"
export CFLAGS="$CFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export CPPFLAGS="$CPPLAGS -I$INSTALL_ROOT/target/root/usr/include"
