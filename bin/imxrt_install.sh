#!/bin/sh
#
# script to install a bootable image (U-Boot) to an external memory (QSPI Flash or HyperFlash) on the IMXRT targets
#

SPL_DEFAULT=$INSTALL_ROOT/u-boot/SPL.flexspi
TPL_DEFAULT=$INSTALL_ROOT/u-boot/u-boot.img
PROJECT_DEFAULT=rootfs
RFS_DEFAULT=none
QSPI_SPL_SIZE=0x10000
QSPI_TPL_SIZE=0x50000
PAGESIZE=0x1000
# shellcheck disable=SC2034
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
	_MCU=imxrt1060
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
	echo "$(basename "$0"): Invalid MCU '$MCU'" >&2
	exit 1
	;;
esac

case "${_MCU}" in
    imxrt1050|imxrt1060)
	SDPHOST_DEFAULT="${FLASHLOADER_PATH}/Tools/sdphost/linux/i386/sdphost"
	BLHOST_DEFAULT="${FLASHLOADER_PATH}/Tools/blhost/linux/i386/blhost"
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
	USB_INSTALLER_DIR=$INSTALL_ROOT/tools/bin/imxrt1170-evk-usb
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
    *)
	echo "$(basename "$0"): Unsupported machine '${_MACHINE}'" >&2
	exit 1
	;;
esac

# If the hardcoded vendor paths above don't exist on this host (e.g. because
# the user installed blhost/sdphost via SPSDK / pip rather than via NXP's
# MCUXpresso Secure Provisioning or Flashloader package), fall back to PATH.
# The -b / -s overrides still take precedence below.
if [ ! -x "${BLHOST_DEFAULT}" ]; then
    BLHOST_DEFAULT="$(command -v blhost 2>/dev/null)"
fi
if [ -n "${SDPHOST_DEFAULT}" ] && [ ! -x "${SDPHOST_DEFAULT}" ]; then
    SDPHOST_DEFAULT="$(command -v sdphost 2>/dev/null)"
fi

BLHOST=${BLHOST_DEFAULT}
SDPHOST=${SDPHOST_DEFAULT}
DFU_UTIL=${DFU_UTIL:-$(command -v dfu-util 2>/dev/null)}

# U-Boot loaded over USB writes the images; the flashloader is used with -f,
# and on the machines that have no USB installer.
if [ -n "${USB_INSTALLER_DIR}" ]; then
    USB_SPL=${USB_INSTALLER_DIR}/SPL.sdp
    USB_TPL=${USB_INSTALLER_DIR}/u-boot-usb.img
    USB_INSTALL=1
fi
USB_SPL_ID=1fc9:0151
USB_TPL_ID=1fc9:0152
USB_UIMAGE_ALT_SIZE=0xf80000

UIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT_DEFAULT}/${PROJECT_DEFAULT}.uImage
if [ "${RFS_DEFAULT}" != "none" ]; then
    RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT_DEFAULT}/${PROJECT_DEFAULT}.${RFS_DEFAULT}
fi

usage() {
    cat <<EOF

     $(basename "$0") - script to install U-Boot and Linux images to external
     QSPI Flash or HyperFlash memory on the IMXRT-based board using SDP over USB

     Usage: $(basename "$0") [-p project] [-t fstype] [options]

     Options:
	-f flashloader.bin	install with the NXP flashloader at this path instead
				of U-Boot over USB; the flashloader is always used on
				machines with no USB installer. Default path is
				${FLASHLOADER_BIN:-not defined}

	-b blhost		specify alternative path to the blhost utility; default
				is ${BLHOST_DEFAULT:-not defined}

	-d sdphost		specify alternative path to the sdphost utility; default
				is ${SDPHOST_DEFAULT:-not defined}

	-S			install the SPL image from the current build environment:
				${SPL_DEFAULT:-not defined}

	-s SPL.flexspi		install the SPL image from an alternative location

	-U			install the main U-Boot image from the current build environment:
				${TPL_DEFAULT:-not defined}

	-u u-boot.img		install the main U-Boot image from an alternative location

	-I			install the Linux uImage from the current build environment:
				${UIMAGE_DEFAULT:-not defined}

	-i uImage		install the Linux uImage from an alternative location

	-R			install the rootfs image from the current build environment:
				${RFSIMAGE_DEFAULT:-not defined}

	-r RFSImage		install the rootfs image from an alternative location

	-p project		set project name; default is ${PROJECT_DEFAULT:-not defined}

	-t fstype		set rootfs type (none, jffs2, or ubi); default is ${RFS_DEFAULT:-not defined}

	-a			install all (short alias for -SUIR)

	-v			enable verbose

     The USB installer runs dfu-util from PATH, or from \$DFU_UTIL. Extra
     dfu-util arguments, such as -p <bus-port> to pick one board, go in
     \$DFU_UTIL_ARGS.

	-h			display this help

EOF
    exit "$1"
}

# Note: blhost_connect and rom_connect are intentionally unquoted below
# to allow word splitting into separate arguments (e.g. "-u 0x15A2,0x0073" -> -u 0x15A2,0x0073)
# shellcheck disable=SC2086
install_images() {
    if [ -n "$SPL_IMG" ]; then
	echo "erasing ${QSPI_SPL_ADDR}+${QSPI_SPL_SIZE} ..." && \
	$BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_SPL_ADDR} ${QSPI_SPL_SIZE} && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_SPL_ADDR} "${SPL_IMG}" || return 1
    fi
    if [ -n "$TPL_IMG" ]; then
	echo "erasing ${QSPI_TPL_ADDR}+${QSPI_TPL_SIZE} ..." && \
	$BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_TPL_ADDR} ${QSPI_TPL_SIZE} && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_TPL_ADDR} "${TPL_IMG}" || return 1
    fi
    if [ -n "$UIMAGE_IMG" ]; then
	echo "erasing ${QSPI_UIMAGE_ADDR}+${QSPI_UIMAGE_SIZE} ..." && \
	$BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_UIMAGE_ADDR} ${QSPI_UIMAGE_SIZE} && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_UIMAGE_ADDR} "${UIMAGE_IMG}" || return 1
    fi
    if [ -n "$RFS_IMG" ]; then
	echo "erasing ${QSPI_RFSIMAGE_ADDR}+${QSPI_RFSIMAGE_SIZE} ..." && \
	$BLHOST ${blhost_connect} -t 500000 -- flash-erase-region ${QSPI_RFSIMAGE_ADDR} ${QSPI_RFSIMAGE_SIZE} && \
	$BLHOST ${blhost_connect} -- write-memory ${QSPI_RFSIMAGE_ADDR} "${RFS_IMG}" || return 1
    fi
}

# shellcheck disable=SC2086
wait_dfu_alt() {
    _n=0
    while [ $_n -lt 30 ]; do
	$DFU_UTIL ${DFU_UTIL_ARGS} -d "$1" -l 2>/dev/null | grep -q "name=\"$2\"" && return 0
	_n=$((_n + 1))
	sleep 1
    done
    echo "no DFU device $1 with alternate '$2' appeared" >&2
    return 1
}

# dfu_run <log> <dfu-util args...>: dfu-util's output is shown only on failure
# shellcheck disable=SC2086
dfu_run() {
    _log=$1
    shift
    $DFU_UTIL ${DFU_UTIL_ARGS} "$@" >"$_log" 2>&1 && return 0
    cat "$_log" >&2
    return 1
}

# dfu_write_verify <id> <alt> <file> <label>: write, then read the region back
dfu_write_verify() {
    echo "writing $4 ..."
    dfu_run "$_tmp/log" -d "$1" -a "$2" -D "$3" || return 1
    rm -f "$_tmp/readback"
    dfu_run "$_tmp/log" -d "$1" -a "$2" -U "$_tmp/readback" || return 1
    cmp -n "$(stat --printf="%s" "$3")" "$3" "$_tmp/readback" >/dev/null || {
	echo "read-back of $4 differs from the file" >&2
	return 1
    }
}

install_images_usb() {
    _tmp=$(mktemp -d) || return 1
    _rc=0
    install_images_usb_ || _rc=1
    rm -rf "$_tmp"
    return $_rc
}

# shellcheck disable=SC2086
install_images_usb_() {
    echo "starting U-Boot over USB ..."
    ${BLHOST} ${rom_connect} -- load-image "${USB_SPL}" >"$_tmp/log" 2>&1 || {
	cat "$_tmp/log" >&2
	return 1
    }
    wait_dfu_alt ${USB_SPL_ID} u-boot && \
    dfu_run "$_tmp/log" -d ${USB_SPL_ID} -a u-boot -D "${USB_TPL}" && \
    dfu_run "$_tmp/log" -d ${USB_SPL_ID} -a 0 -e && \
    wait_dfu_alt ${USB_TPL_ID} kernel || return 1

    if [ -n "$SPL_IMG" ]; then
	dfu_write_verify ${USB_TPL_ID} spl "$SPL_IMG" "$SPL_IMG" || return 1
    fi
    if [ -n "$TPL_IMG" ]; then
	dfu_write_verify ${USB_TPL_ID} u-boot "$TPL_IMG" "$TPL_IMG" || return 1
    fi
    if [ -n "$UIMAGE_IMG" ]; then
	dfu_write_verify ${USB_TPL_ID} kernel "$UIMAGE_IMG" "$UIMAGE_IMG" || return 1
    fi
    if [ -n "$RFS_IMG" ]; then
	# Fill the rest of the window with 0xFF: nothing of an older rootfs remains
	tr '\000' '\377' </dev/zero | head -c $((QSPI_RFSIMAGE_SIZE)) >"$_tmp/rootfs"
	dd if="$RFS_IMG" of="$_tmp/rootfs" conv=notrunc 2>/dev/null
	dfu_write_verify ${USB_TPL_ID} rootfs "$_tmp/rootfs" "$RFS_IMG" || return 1
    fi
    dfu_run "$_tmp/log" -d ${USB_TPL_ID} -a 0 -e || return 1
    echo "done; set the boot mode to QSPI flash and reset the board"
}

# shellcheck disable=SC2086
configure_mem_imxrt10xx() {
    echo "starting flashloader ..."
    $SDPHOST ${rom_connect} -- error-status && \
    $SDPHOST ${rom_connect} -- write-file 0x20000000 "${FLASHLOADER_BIN}" && \
    $SDPHOST ${rom_connect} -- jump-address 0x20000400 && sleep 3 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xC0000007 word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000
}

# shellcheck disable=SC2086
configure_mem_imxrt1170() {
    echo "starting flashloader ..."
    ${BLHOST} ${rom_connect} -- load-image "${FLASHLOADER_BIN}" && sleep 3 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 0xCF900001 word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000 && \
    $BLHOST ${blhost_connect} -- fill-memory 0x2000 4 "${FLEXSPI_MEM_CONFIG}" word && \
    $BLHOST ${blhost_connect} -- configure-memory 9 0x2000
}

while getopts "ab:d:f:hIi:p:Rr:Ss:t:vUu:" opt
do
    case "$opt" in
	h) usage 0;;
	b) BLHOST=$OPTARG ;;
	d) SDPHOST=$OPTARG ;;
	f) FLASHLOADER_BIN=$OPTARG; USB_INSTALL= ;;
	a) INSTALL_ALL=1 ;;
	i) [ -n "$UIMAGE_IMG" ] && usage 128 || UIMAGE_IMG=$OPTARG ;;
	I) INSTALL_UIMAGE=1 ;;
	p) { [ -n "$UIMAGE_IMG" ] && [ -n "$RFS_IMG" ]; } || [ -n "$PROJECT" ] && usage 128 || PROJECT=${OPTARG}
	   UIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT}/${PROJECT}.uImage
	   if [ -n "$RFST" ]; then
	       RFST__=${RFST}
	   else
	       # No -t: derive the fstype from the project Makefile (FLASHFS_TYPE, per-MCU).
	       RFST__=$(make -C "$INSTALL_ROOT/projects/${PROJECT}" MCU="$MCU" -pq 2>/dev/null \
		   | sed -n 's/^FLASHFS_TYPE[[:space:]]*:*=[[:space:]]*//p' | head -1)
	       [ -z "$RFST__" ] && RFST__=${RFS_DEFAULT}
	   fi
	   RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJECT}/${PROJECT}.${RFST__}
	   if [ "$RFST__" = "none" ]; then RFSIMAGE_DEFAULT=""; fi
	   ;;
	r) [ -n "$RFS_IMG" ] && usage 128 || RFS_IMG=$OPTARG ;;
	R) INSTALL_RFS=1 ;;
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
	t) { [ -n "$RFS_IMG" ] || [ -n "$RFST" ]; } && usage 128 || RFST=${OPTARG}
	   if [ -n "$PROJECT" ]; then  PROJ__=${PROJECT}; else PROJ__=${PROJECT_DEFAULT}; fi
	   RFSIMAGE_DEFAULT=$INSTALL_ROOT/projects/${PROJ__}/${PROJ__}.${RFST}
	   if [ "$RFST" = "none" ]; then RFSIMAGE_DEFAULT=""; fi
	   ;;
	u) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$OPTARG ;;
	U) [ -n "$TPL_IMG" ] && usage 128 || TPL_IMG=$TPL_DEFAULT ;;
	v) set -x ;;
	*) echo "$(basename "$0"): Invalid option '$OPTARG'" >&2 ; usage 128 ;;
	esac
done

# The image defaults (-a for all, and the per-image -I / -R) are resolved here,
# after option parsing, so they reflect the final -p / -t selection regardless
# of the order the options were given. Each is mutually exclusive with its
# explicit-path counterpart (-i / -r / ...).
if [ -n "$INSTALL_ALL" ]; then
    [ -n "$UIMAGE_IMG$RFS_IMG$SPL_IMG$TPL_IMG" ] && usage 128
    [ "$SPL_DEFAULT" != "UNSUPPORTED" ] && SPL_IMG=$SPL_DEFAULT
    TPL_IMG=$TPL_DEFAULT
    UIMAGE_IMG=$UIMAGE_DEFAULT
    [ -n "$RFSIMAGE_DEFAULT" ] && RFS_IMG=$RFSIMAGE_DEFAULT
fi
if [ -n "$INSTALL_UIMAGE" ]; then
    [ -n "$UIMAGE_IMG" ] && usage 128
    UIMAGE_IMG=$UIMAGE_DEFAULT
fi
if [ -n "$INSTALL_RFS" ]; then
    [ -n "$RFS_IMG" ] && usage 128
    if [ -z "$RFSIMAGE_DEFAULT" ]; then
        echo "no rootfs image configured; use -p and -t to specify project and fstype" >&2
        usage 1
    fi
    RFS_IMG=$RFSIMAGE_DEFAULT
fi

[ -n "$SPL_IMG" ] && [ ! -f "$SPL_IMG" ] && echo "can't find image $SPL_IMG" && usage 1;
[ -n "$TPL_IMG" ] && [ ! -f "$TPL_IMG" ] && echo "can't find image $TPL_IMG" && usage 1;

if [ -n "$USB_INSTALL" ]; then
    for _f in "$USB_SPL" "$USB_TPL"; do
	[ -f "$_f" ] || { echo "can't find USB installer image $_f"; usage 1; }
    done
    if [ -z "$DFU_UTIL" ] || [ ! -x "$DFU_UTIL" ]; then
	echo "can't find dfu-util; install it, set DFU_UTIL, or use -f flashloader.bin"
	usage 1
    fi
elif [ ! -f "$FLASHLOADER_BIN" ]; then
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
    if [ -f "$UIMAGE_IMG" ]; then
	QSPI_UIMAGE_SIZE=$(stat --printf="%s" "$UIMAGE_IMG")
	QSPI_UIMAGE_SIZE=$(((QSPI_UIMAGE_SIZE + PAGESIZE) & ~(PAGESIZE-1)))
	QSPI_UIMAGE_SIZE=$(printf 0x%x $QSPI_UIMAGE_SIZE)
    else
	echo "can't find kernel image file $UIMAGE_IMG"; usage 1;
    fi
fi

if [ -n "$RFS_IMG" ]; then
    if [ ! -f "$RFS_IMG" ]; then
	echo "can't find rootfs image $RFS_IMG"; usage 1;
    fi
fi

# The kernel's erase must end where the root filesystem starts: always on the
# RT1050/RT1060, whose U-Boot reads a fixed-size kernel, elsewhere with -R.
if [ -n "$UIMAGE_IMG" ]; then
    case "${_MCU}" in
	imxrt1050|imxrt1060) _kernel_limit=1 ;;
	*) _kernel_limit=${RFS_IMG:+1} ;;
    esac
    if [ -n "$_kernel_limit" ] && \
       [ $((QSPI_UIMAGE_ADDR + QSPI_UIMAGE_SIZE)) -gt $((QSPI_RFSIMAGE_ADDR)) ]; then
	echo "kernel image $UIMAGE_IMG does not fit below the rootfs at" \
	     "${QSPI_RFSIMAGE_ADDR}; build it with FLASHFS_TYPE set" >&2
	exit 1
    fi
fi

if [ -n "$USB_INSTALL" ]; then
    [ -n "$SPL_IMG" ] && [ "$(stat --printf="%s" "$SPL_IMG")" -gt $((QSPI_SPL_SIZE)) ] && \
	echo "SPL image $SPL_IMG is larger than ${QSPI_SPL_SIZE}" >&2 && exit 1
    [ -n "$TPL_IMG" ] && [ "$(stat --printf="%s" "$TPL_IMG")" -gt $((QSPI_TPL_SIZE)) ] && \
	echo "U-Boot image $TPL_IMG is larger than ${QSPI_TPL_SIZE}" >&2 && exit 1
    [ -n "$UIMAGE_IMG" ] && [ $((QSPI_UIMAGE_SIZE)) -gt $((USB_UIMAGE_ALT_SIZE)) ] && \
	echo "kernel image $UIMAGE_IMG is larger than ${USB_UIMAGE_ALT_SIZE}" >&2 && exit 1
    [ -n "$RFS_IMG" ] && [ "$(stat --printf="%s" "$RFS_IMG")" -gt $((QSPI_RFSIMAGE_SIZE)) ] && \
	echo "rootfs image $RFS_IMG is larger than ${QSPI_RFSIMAGE_SIZE}" >&2 && exit 1
fi

[ -z "$SPL_IMG" ] && [ -z "$TPL_IMG" ] && [ -z "$UIMAGE_IMG" ] && [ -z "$RFS_IMG" ] && \
    echo "no images specified to install" && usage 1

echo "Target: ${_MCU} (${_MACHINE})"
[ -n "$SPL_IMG" ]    && echo "  SPL:    $SPL_IMG"
[ -n "$TPL_IMG" ]    && echo "  U-Boot: $TPL_IMG"
[ -n "$UIMAGE_IMG" ] && echo "  Kernel: $UIMAGE_IMG"
[ -n "$RFS_IMG" ]    && echo "  RootFS: $RFS_IMG"
echo ""

if [ "${_MCU}" = "imxrt1050" ] || [ "${_MCU}" = "imxrt1060" ]; then
    configure_mem_imxrt10xx || exit 1
elif [ -n "$USB_INSTALL" ]; then
    install_images_usb || exit 1
    exit 0
elif [ "${_MCU}" = "imxrt1170" ]; then
    configure_mem_imxrt1170 || exit 1
fi
install_images
