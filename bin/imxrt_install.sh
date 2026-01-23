#!/bin/sh
#
# script to install a bootable image (U-Boot) to an external memory (QSPI Flash) on the IMXRT targets
#

SPL_DEFAULT=$INSTALL_ROOT/u-boot/SPL.flexspi
TPL_DEFAULT=$INSTALL_ROOT/u-boot/u-boot.img
PROJECT_DEFAULT=rootfs
RFS_DEFAULT=none
QSPI_SPL_SIZE=0x10000
QSPI_TPL_SIZE=0x50000
PAGESIZE=0x1000
blhost_connect="-u 0x15A2,0x0073"

if [ -z "$MCU" ]; then
    echo "Cross Development Environment is not activated"
    exit 1
fi

case "${MCU}" in
    IMXRT105X_NXPEVK)
	_MCU=imxrt1050
	_MACHINE=imxrt1050_nxpevk
	FLASHLOADER_PATH=$INSTALL_ROOT/tools/Flashloader_i.MXRT1050_GA/Flashloader_RT1050_1.1
	FLASHLOADER_BIN="${FLASHLOADER_PATH}/Tools/mfgtools-rel/Profiles/MXRT105X/OS Firmware/ivt_flashloader.bin"
	rom_connect="-u 0x1FC9,0x0130"
	;;
    IMXRT106X_NXPEVK)
	_MCU=imxrt1050
	_MACHINE=imxrt1060_nxpevk
	FLASHLOADER_PATH=$INSTALL_ROOT/tools/Flashloader_RT106x_1.0_GA
	FLASHLOADER_BIN="${FLASHLOADER_PATH}/Tools/mfgtools-rel/Profiles/MXRT106X/OS Firmware/ivt_flashloader.bin"
	rom_connect="-u 0x1FC9,0x0135"
	;;
    IMXRT117X_NXPEVK)
	_MCU=imxrt1170
	_MACHINE=imxrt1170_nxpevk
	;;
    MAAXBOARD_RT)
	_MCU=imxrt1170
	_MACHINE=maaxboard_rt
	;;
    *)
	echo "`basename $0`: Invalid MCU '$MCU'" >&2
	exit 1
	;;
esac

case "${_MCU}" in
    imxrt1050|imxrt1060)
	SDPHOST_DEFAULT="${FLASHLOADER_PATH}/Tools/sdphost/linux/i386/sdphost"
	BLHOST_DEFAULT="${FLASHLOADER_PATH}/Tools/blhost/linux/i386/blhost"
	PROJECT_DEFAULT=rootfs_flash
	RFS_DEFAULT=jffs2
	;;
    imxrt1170)
	BLHOST_DEFAULT="/opt/nxp/MCUX_Provi_25.03/bin/_internal/tools/spsdk/blhost"
	SDPHOST_DEFAULT=""
	FLASHLOADER_BIN=$INSTALL_ROOT/tools/bin/unsigned_MIMXRT1176_flashloader.bin
	rom_connect="-u 0x1FC9,0x013D"
	;;
esac

case "${_MACHINE}" in
    imxrt1050_nxpevk|imxrt1060_nxpevk)
	QSPI_SPL_ADDR=0x60000000
	QSPI_TPL_ADDR=0x60010000
	QSPI_UIMAGE_ADDR=0x60080000
	QSPI_RFSIMAGE_ADDR=0x60480000
	QSPI_RFSIMAGE_SIZE=0x380000
	;;
    imxrt1170_nxpevk)
	QSPI_SPL_ADDR=0x30000000
	QSPI_TPL_ADDR=0x30010000
	QSPI_UIMAGE_ADDR=0x30080000
	QSPI_RFSIMAGE_ADDR=0x30880000
	QSPI_RFSIMAGE_SIZE=0x780000
	FLEXSPI_MEM_CONFIG=0xC0000007
	;;
    maaxboard_rt)
	QSPI_TPL_ADDR=0x30000000
	QSPI_UIMAGE_ADDR=0x30100000
	QSPI_RFSIMAGE_ADDR=0x30E00000
	QSPI_RFSIMAGE_SIZE=0x01200000
	SPL_DEFAULT=UNSUPPORTED
	TPL_DEFAULT=$INSTALL_ROOT/u-boot/flash.bin
	FLEXSPI_MEM_CONFIG=0xC0233007
	PAGESIZE=0x40000
	;;
esac

BLHOST=${BLHOST_DEFAULT}
SDPHOST=${SDPHOST_DEFAULT}

UIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT_DEFAULT}/${PROJECT_DEFAULT}.uImage
if [ "${RFS_DEFAULT}" != "none" ]; then
    RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT_DEFAULT}/${PROJECT_DEFAULT}.${RFS_DEFAULT}
fi

usage() {
    cat <<EOF

     `basename $0` - script to install the bootable U-Boot and Linux images to external
     QSPI Flash or HypeFlash memory on the IMXRT-based board using SDP over USB

     Usage: `basename $0` [-p project] [-t fstype] [options]

     Options:
	-f flashloader.bin	specify alternative path to the flashloader.bin file;
				default is:
				$FLASHLOADER_BIN

	-b blhost		specify alternative path to the blhost utility; default
				is $BLHOST_DEFAULT

	-d sdphost		specify alternative path to the sdphost utility; default
				is $SDPHOST_DEFAULT

	-S			install the SPL image from the current build environment:
				$SPL_DEFAULT

	-s SPL.flexspi		install the SPL image from an alternative location

	-U			install the main U-Boot image from the current build environment:
				$SPL_DEFAULT

	-u u-boot.img		install the main U-Boot image from an alternative location

	-I			install the Linux uImage from the current build environment:
				$UIMAGE_DEFAULT

	-i uImage		install the Linux uImage from an alternative location

	-R			install the rootfs Image from the current build environment:
				$RFSIMAGE_DEFAULT

	-r RFSImage		install the rootfs Image from an alternative location

	-p project		project name

	-t fstype		rootfs type (none or jffs2 or ubi)

	-a			install all - short alias for the -SUIR options

	-v			enable verbose

	-h			display this help

EOF
    exit $1
}

install_images() {
    [ -z ${SPL_IMG+x} ] || ( \
	echo "erasing ${QSPI_SPL_ADDR}+${QSPI_SPL_SIZE} ..." \
	&& $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_SPL_ADDR} ${QSPI_SPL_SIZE}  && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_SPL_ADDR} ${SPL_IMG} ) && \
    [ -z ${TPL_IMG+x} ] || ( \
	echo "erasing ${QSPI_TPL_ADDR}+${QSPI_TPL_SIZE} ..." \
	&& $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_TPL_ADDR} ${QSPI_TPL_SIZE}  && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_TPL_ADDR} ${TPL_IMG} ) && \
    [ -z ${UIMAGE_IMG+x} ] || (\
	echo "erasing ${QSPI_UIMAGE_ADDR}+${QSPI_UIMAGE_SIZE} ..." \
	&& $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_UIMAGE_ADDR} ${QSPI_UIMAGE_SIZE}  && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_UIMAGE_ADDR} ${UIMAGE_IMG} )
    [ -z ${RFS_IMG+x} ] || (\
	echo "erasing ${QSPI_RFSIMAGE_ADDR}+${QSPI_RFSIMAGE_SIZE} ..." \
	&& $BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_RFSIMAGE_ADDR} ${QSPI_RFSIMAGE_SIZE}  && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_RFSIMAGE_ADDR} ${RFS_IMG} )
}

configure_mem_imxrt10xx() {
    echo "starting flashloader ..."
    $SDPHOST ${rom_connect} -- error-status && \
    $SDPHOST ${rom_connect} -- write-file 0x20000000 "${FLASHLOADER_BIN}" && \
    $SDPHOST ${rom_connect} -- jump-address 0x20000400 && sleep 3 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xC0000007 word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000
}

configure_mem_imxrt1170() {
    echo "starting flashloader ..."
    ${BLHOST} ${rom_connect} -- load-image ${FLASHLOADER_BIN} && sleep 3 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xCF900001 word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 ${FLEXSPI_MEM_CONFIG} word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000
}

while getopts "ab:f:hIi:p:Rr:Ss:t:vUu:" opt
do
    case "$opt" in
	h) usage 0;;
	b) BLHOST=$OPTARG ;;
	f) FLASHLOADER_BIN=$OPTARG ;;
	a) [ -n "$UIMAGE_IMG$RFS_IMG$SPL_IMG$TPL_IMG" ] && usage 128 || \
	   UIMAGE_IMG=$UIMAGE_DEFAULT RFS_IMG=$RFSIMAGE_DEFAULT SPL_IMG=$SPL_DEFAULT TPL_IMG=$TPL_DEFAULT ;;
	i) [ -n "$UIMAGE_IMG" ] && usage 128 || UIMAGE_IMG=$OPTARG ;;
	I) [ -n "$UIMAGE_IMG" ] && usage 128 || UIMAGE_IMG=$UIMAGE_DEFAULT ;;
	p) [ -n "$UIMAGE_IMG" -a -n "$RFS_IMG" -o -n "$PROJECT" ] && usage 128 || PROJECT=${OPTARG}
	   UIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT}/${PROJECT}.uImage
	   if [ -n "$RFST" ]; then  RFST__=${RFST}; else RFST__=${RFST_DEFAULT}; fi
	   RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT}/${PROJECT}.${RFST__}
	   if [ "$RFST__" = "none" ]; then RFSIMAGE_DEFAULT=""; fi
	   ;;
	r) [ -n "$RFS_IMG" ] && usage 128 || RFS_IMG=$OPTARG ;;
	R) [ -n "$RFS_IMG" ] && usage 128 || RFS_IMG=$RFSIMAGE_DEFAULT ;;
	s) [ -n "$SPL_IMG" ] && usage 128
	   if [ "$SPL_DEFAULT" != "UNSUPPORTED" ]; then
	       SPL_IMG=$OPTARG
	   else
	       echo installing SPL image separately unsupported with the ${_MACHINE} machine, ignoring -s
	   fi
	   ;;
	S) [ -n "$SPL_IMG" ] && usage 128
	   if [ "$SPL_DEFAULT" != "UNSUPPORTED" ]; then
	       SPL_IMG=$SPL_DEFAULT
	   else
	       echo installing SPL image separately unsupported with the ${_MACHINE} machine, ignoring -S
	   fi
	   ;;
	t) [ -n "$RFS_IMG" -o -n "$RFST" ] && usage 128 || RFST=${OPTARG}
	   if [ -n "$PROJECT" ]; then  PROJ__=${PROJECT}; else PROJ__=${PROJECT_DEFAULT}; fi
	   RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJ__}/${PROJ__}.${RFST}
	   if [ "$RFST" = "none" ]; then RFSIMAGE_DEFAULT=""; fi
	   ;;
	u) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$OPTARG ;;
	U) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$TPL_DEFAULT ;;
	v) set -x ;;
	*) echo "`basename $0`: Invalid option '$OPTARG'" >&2 ; usage 128 ;;
	esac
done

[ -n "$SPL_IMG" ] && [ ! -f $SPL_IMG ] && echo "can't find image $SPL_IMG" && usage 1;
[ -n "$TPL_IMG" ] && [ ! -f $TPL_IMG ] && echo "can't find image $TPL_IMG" && usage 1;

if [ ! -f "$FLASHLOADER_BIN" ]; then
   echo "can't find flashloader image $FLASHLOADER_BIN"; usage 1;
fi

if [ ! -f "$BLHOST" ]; then
   echo "can't find the blhost tool $BLHOST"; usage 1;
fi

if [ -n "$SDPHOST" ]; then
    if [ ! -f "$SDPHOST" ]; then
	echo "can't find the sdphost tool $SDPHOST"; usage 1;
    fi
fi

if [ -n "$UIMAGE_IMG" ]; then
    if [ -f $UIMAGE_IMG ]; then
	QSPI_UIMAGE_SIZE=`stat --printf="%s" $UIMAGE_IMG`
	QSPI_UIMAGE_SIZE=$((($QSPI_UIMAGE_SIZE + $PAGESIZE) & ~($PAGESIZE-1)))
	QSPI_UIMAGE_SIZE=`printf 0x%x $QSPI_UIMAGE_SIZE`
    else
	echo "can't find kernel image file $UIMAGE_IMG"; usage 1;
    fi
fi

if [ -n "$RFS_IMG" ]; then
    if [ ! -f $RFS_IMG ]; then
	echo "can't find rootfs image $RFS_IMG"; usage 1;
    fi
fi

[ -z ${SPL_IMG+x} ] && [ -z ${TPL_IMG+x} ] && [ -z ${UIMAGE_IMG+x} ] && [ -z ${RFS_IMG+x} ] && \
    echo "no images specified to install" && usage 1

if [ "${_MCU}" = "imxrt1050" -o "${_MCU}" = "imxrt1060" ]; then
    configure_mem_imxrt10xx
elif [ "${_MCU}" = "imxrt1170" ]; then
    configure_mem_imxrt1170
fi
install_images
