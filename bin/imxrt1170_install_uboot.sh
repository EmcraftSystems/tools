#!/bin/sh
#
# script to install a bootable image (U-Boot) to an external memory (QSPI Flash) on the IMXRT1170 target
#

BLHOST="/opt/nxp/MCUX_Provi_v10/bin/_internal/tools/spsdk/blhost"
FLASHLOADER_BIN=$INSTALL_ROOT/tools/bin/unsigned_MIMXRT1176_flashloader.bin

SPL_DEFAULT=$INSTALL_ROOT/u-boot/SPL.flexspi
TPL_DEFAULT=$INSTALL_ROOT/u-boot/u-boot.img
UIMAGE_DEFAULT=$INSTALL_ROOT/projects/rootfs/rootfs.uImage

usage() {
    cat <<EOF

     `basename $0` - script to install the bootable U-Boot and Linux images to external
     QSPI Flash memory on the IMXRT1170-based board using SDP over USB

     Usage: `basename $0` [options]

     Options:
	-f flashloader.bin	specify alternative path to the flashloader.bin file;
				default is tools/bin/unsigned_MIMXRT1176_flashloader.bin
				in linux-cm-imxrt-3.0.x distribution:
				$FLASHLOADER_BIN

	-b blhost		specify alternative path to the blhost utility; default
				is one from the MCUXpresso Secure Provisioning Tool v10 installation:
				$BLHOST

	-S			install the SPL image from current distribution:
				$SPL_DEFAULT

	-s SPL.flexspi		install the SPL image from an alternative location

	-U			install the main U-Boot image from current distribution:
				$TPL_DEFAULT

	-u u-boot.img		install the main U-Boot image from an alternative location

	-I			install the Linux uImage from current distribution:
				$UIMAGE_DEFAULT

	-i uImage		install the Linux uImage from an alternative location

	-a			install all - short alias for the -SUI options

	-v			enable verbose

	-h			display this help

EOF
    exit $1
}

QSPI_SPL_ADDR=0x30000000
QSPI_TPL_ADDR=0x30010000
QSPI_UIMAGE_ADDR=0x30080000

QSPI_SPL_SIZE=0x10000
QSPI_TPL_SIZE=0x50000

while getopts "ab:f:hIi:Ss:vUu:" opt
do
    case "$opt" in
	h) usage 0;;
	b) BLHOST=$OPTARG ;;
	f) FLASHLOADER_BIN=$OPTARG ;;
	a) [ -n "$UIMAGE_IMG$SPL_IMG$TPL_IMG" ] && usage 128 || UIMAGE_IMG=$UIMAGE_DEFAULT SPL_IMG=$SPL_DEFAULT TPL_IMG=$TPL_DEFAULT ;;
	i) [ -n "$UIMAGE_IMG" ] && usage 128 || UIMAGE_IMG=$OPTARG ;;
	I) [ -n "$UIMAGE_IMG" ] && usage 128 || UIMAGE_IMG=$UIMAGE_DEFAULT ;;
	s) [ -n "$SPL_IMG" ] && usage 128 || SPL_IMG=$OPTARG ;;
	S) [ -n "$SPL_IMG" ] && usage 128 || SPL_IMG=$SPL_DEFAULT ;;
	u) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$OPTARG ;;
	U) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$TPL_DEFAULT ;;
	v) set -x ;;
	*) echo "`basename $0`: Invalid option '$OPTARG'" >&2 ; usage 128 ;;
	esac
done

[ -n "$SPL_IMG" ] && [ ! -f $SPL_IMG ] && echo "can't find image $SPL_IMG" && usage 1;
[ -n "$TPL_IMG" ] && [ ! -f $TPL_IMG ] && echo "can't find image $TPL_IMG" && usage 1;

PAGESIZE=0x1000

if [ -n "$UIMAGE_IMG" ]; then
    if [ -f $UIMAGE_IMG ]; then
	QSPI_UIMAGE_SIZE=`stat --printf="%s" $UIMAGE_IMG`
	QSPI_UIMAGE_SIZE=$((($QSPI_UIMAGE_SIZE + $PAGESIZE) & ~($PAGESIZE-1)))
	QSPI_UIMAGE_SIZE=`printf 0x%x $QSPI_UIMAGE_SIZE`
    else
	echo "can't find image $UIMAGE_IMG"; usage 1;
    fi
fi

rom_connect="-u 0x1FC9,0x013D"
blhost_connect="-u 0x15A2,0x0073"

echo "starting flashloader ..." \
    && ${BLHOST} ${rom_connect} -- load-image ${FLASHLOADER_BIN} && sleep 3 && \
$BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xCF900001 word && \
$BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
$BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xC0000007 word && \
$BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
( [ -z ${SPL_IMG+x} ] || ( \
      echo "erasing ${QSPI_SPL_ADDR}+${QSPI_SPL_SIZE} ..." \
      && $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_SPL_ADDR} ${QSPI_SPL_SIZE}  && \
      $BLHOST ${blhost_connect} -- write-memory ${QSPI_SPL_ADDR} ${SPL_IMG} ) ) && \
( [ -z ${TPL_IMG+x} ] || ( \
      echo "erasing ${QSPI_TPL_ADDR}+${QSPI_TPL_SIZE} ..." \
      && $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_TPL_ADDR} ${QSPI_TPL_SIZE}  && \
      $BLHOST ${blhost_connect} -- write-memory ${QSPI_TPL_ADDR} ${TPL_IMG} ) ) && \
( [ -z ${UIMAGE_IMG+x} ] || ( \
      echo "erasing ${QSPI_UIMAGE_ADDR}+${QSPI_UIMAGE_SIZE} ..." \
      && $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_UIMAGE_ADDR} ${QSPI_UIMAGE_SIZE}  && \
      $BLHOST ${blhost_connect} -- write-memory ${QSPI_UIMAGE_ADDR} ${UIMAGE_IMG} ) )
