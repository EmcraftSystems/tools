export INSTALL_ROOT=`pwd`
export ELDK_ROOTFS=/opt/eldk-5.3/armv7a/rootfs-qte-sdk
export MQX_TOOLCHAIN_DIR=/usr/local/arm-2012
export HOST_PYTHON_EXE_PATH=/usr/bin/python

# Define the MCU architecture
export MCU=VF6

eval `eldk-switch.sh -r 5.3 armv7a`

