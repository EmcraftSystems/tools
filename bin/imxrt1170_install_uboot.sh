#!/bin/sh
#
# script to install a bootable image (U-Boot) to an external memory (QSPI Flash) on the IMXRT1170 target
#

usage() {
    echo "`basename $0` [-f path the flashloader.bin] [-p path to the Secure Provisioning Tool] [-u path to U-Boot] [-v] [-h]"
    echo "Install bootable U-Boot image to the QSPI Flash on IMXRT1170 target"
    echo "where:"
    echo "'f' option - override the default flashloader binary file"
    echo "'p' option - specify alternative path to the installation of the MCUXpresso Secure Provisioning Tool"
    echo "'s' option - install only the SPL image and skip u-boot.img"
    echo "'u' option - specify alternative path to the directory containung the U-Boot binaries"
    echo "'v' option - enable verbose"
    echo "'h' option - help"
}

while getopts "f:hp:svu:" opt
do
    case "$opt" in
        h) usage ; exit 0 ;;
        f) FLASHLOADER_BIN=$OPTARG ;;
        p) MCUX_PROVI_PATH=$OPTARG ;;
	s) SKIP_UBOOT_IMG=1 ;;
	v) set -x ;;
        u) UBOOT_PATH=$OPTARG ;;
        *) echo "`basename $0`: Invalid option '$OPTARG'" >&2 ; exit -1 ;;
        esac
done

if [ -z ${MCUX_PROVI_PATH+x} ]; then
    MCUX_PROVI_PATH="/opt/nxp/MCUX_Provi_v9"
fi
if [ -z ${UBOOT_PATH+x} ]; then
    UBOOT_PATH=$INSTALL_ROOT/u-boot
fi
if [ -z ${FLASHLOADER_BIN+x} ]; then
    FLASHLOADER_BIN=$INSTALL_ROOT/tools/bin/unsigned_MIMXRT1176_flashloader.bin
fi

QSPI_SPL_BASEADDR=0x30000000
QSPI_TPL_BASEADDR=0x30010000
if [ -z ${SKIP_UBOOT_IMG+x} ]; then
    UBOOT_TOTAL_SIZE=0x60000
else
    UBOOT_TOTAL_SIZE=0x10000
fi
SPL_IMG=SPL.flexspi
TPL_IMG=u-boot.img

BLHOST=${MCUX_PROVI_PATH}/bin/_internal/tools/spsdk/blhost
rom_connect="-u 0x1FC9,0x013D"
blhost_connect="-u 0x15A2,0x0073"

${BLHOST} ${rom_connect} -- load-image ${FLASHLOADER_BIN} && sleep 3 && \
$BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xCF900001 word && \
$BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
$BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xC0000007 word && \
$BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
$BLHOST ${blhost_connect} -t 50000 -- flash-erase-region ${QSPI_SPL_BASEADDR} ${UBOOT_TOTAL_SIZE} && \
$BLHOST ${blhost_connect} -- write-memory ${QSPI_SPL_BASEADDR} ${UBOOT_PATH}/${SPL_IMG} && \
( [ ! -z ${SKIP_UBOOT_IMG+x} ] || $BLHOST ${blhost_connect} -- write-memory ${QSPI_TPL_BASEADDR} ${UBOOT_PATH}/${TPL_IMG} )
