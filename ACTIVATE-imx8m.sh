export YOCTO_ROOT=/opt/fsl-imx-fb/4.9.11-mx8_alpha
export IPK_REPO=$YOCTO_ROOT/packages

export INSTALL_ROOT=`pwd`

export HOST_PYTHON_EXE_PATH=/usr/bin/python

source $YOCTO_ROOT/environment-setup-aarch64-poky-linux
unset PYTHONHOME
unset CCACHE_PATH

export MCU=IMX8M-SOM

export CXXFLAGS="$CXXFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export LDFLAGS="$LDFLAGS -L$INSTALL_ROOT/target/root/usr/lib"
export CFLAGS="$CFLAGS -I$INSTALL_ROOT/target/root/usr/include"
export CPPFLAGS="$CPPLAGS -I$INSTALL_ROOT/target/root/usr/include"
