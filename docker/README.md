# Docker-based build environment

This directory contains a reproducible containerized build environment for
the Emcraft Linux-CM BSP -- uClinux for the NXP i.MX RT family. The
container bakes in every host build dependency required by the kernel,
U-Boot, buildroot, and the project apps. The release tree -- including
the `arm-buildroot-uclinuxfdpiceabi-` cross-toolchain you extracted into
`tools/` -- is bind-mounted into the container at run time, so the
container runs the same toolchain you'd use on the host. The active
target is selected by `ACTIVATE.sh` in the release tree.

## Why use it

- No host-side installation of the ~30 build dependencies.
- Identical build environment across developer machines, CI, and release
  verification.
- Same toolchain behaviour inside and outside the container.

## Prerequisites

- Docker Engine 20.10 or newer, with the current user in the `docker` group
  (or access to `sudo docker`).
- About 600 MB of free disk space for the built image.
- A network connection the first time `make` triggers a buildroot download.
- The FDPIC SDK extracted into `tools/<sdk-name>/` per the standard release
  deployment. A symlink to an external SDK install works too.

## Image build

`run.sh` builds the image on first invocation if it's missing, so for the
default flow you don't need a separate setup step -- just go straight to
"Daily usage" below.

To build (or rebuild) ahead of time, run:

```
./tools/docker/run.sh --build
```

The image is tagged `emcraft/linux-cm-build:<version>`, where
`<version>` is the first `N.N.N` triple in `_MANIFEST` at the
release-tree root.

Set `NO_AUTO_BUILD=1` if you'd rather `run.sh` error out when the image
is missing or stale instead of building automatically.

## Daily usage

Run commands against the release tree from anywhere inside it:

```
./tools/docker/run.sh                              # interactive shell at the release root
./tools/docker/run.sh make -C projects/rootfs      # one-shot build from the release root
cd projects/rootfs && ../../tools/docker/run.sh make   # one-shot build from a subdir
```

Pick an MCU target with `-m` / `--mcu` (validated by `ACTIVATE.sh` inside
the container; the supported list is printed on a typo). The flag must
come before the command. Inheriting `$MCU` from the host shell works too:

```
./tools/docker/run.sh --mcu MAAXBOARD_RT make
./tools/docker/run.sh -m STM32H7
MCU=IMXRT117X_NXPEVK ./tools/docker/run.sh make
```

The wrapper:

- Bind-mounts the release tree at `/work` read-write.
- Preserves your current working directory inside the container.
- Maps your UID/GID so that build outputs are owned by you, not by root.
- Sources `ACTIVATE.sh` so `MCU`, `CROSS_COMPILE`, `PATH`, etc. are set
  exactly as on a host install -- the cross-toolchain at
  `/work/tools/<sdk-name>/` and the prebuilt utilities at `/work/tools/bin/`
  are reached via the bind mount.

To test that the environment is active inside the container:

```
$ ./tools/docker/run.sh echo '$MCU'
IMXRT117X_NXPEVK
```

## What's in the image vs. on the host

- `/work` inside the container is your extracted release tree on the host.
  All edits, build outputs, and buildroot downloads persist there.
- The cross-toolchain at `tools/<sdk-name>/` and the prebuilt utilities at
  `tools/bin/` (e.g. `mkimage`, `fdpichdr`, `imxrt_install.sh`,
  MCU-family-specific flashloader blobs) are reached via the `/work` bind
  mount; they are **not** baked into the image. Extract the SDK into
  `tools/` once on the host (or symlink it to an external install) and the
  container picks it up automatically. Some `tools/bin/` utilities are
  32-bit ELF, so the image installs `libc6:i386` to run them.

## Optional: in-container board flashing (`WITH_INSTALLER`)

By default the image is build-only. To run `imxrt_install.sh` inside the
container too, build a separate variant with the `spsdk` Python package
(provides `blhost` and `sdphost`) baked in:

```
WITH_INSTALLER=1 ./tools/docker/run.sh --build
```

That produces `emcraft/linux-cm-build:<version>-installer` (~150 MB
heavier than the default). Then run with the same flag set:

```
WITH_INSTALLER=1 ./tools/docker/run.sh imxrt_install.sh -a
```

`run.sh` picks the `-installer` image variant and bind-mounts the host
`/dev` (so the i.MX RT mid-flash chip re-enumeration is visible inside
the container) plus grants cgroup permissions for USB-189 and the
dynamically-allocated `hidraw` major.

Linux only -- on macOS / Windows / WSL2 the host has no `/dev/bus/usb`,
so the in-container flow can't reach the board. Flash from the host
directly on those platforms (or any time you'd rather not maintain the
extra image variant): `pip install --user spsdk` and run
`./tools/bin/imxrt_install.sh -a` outside the container.

## Troubleshooting

- **`docker: permission denied`** — your user is not in the `docker` group.
  Either `sudo usermod -aG docker $USER` and log back in, or prefix commands
  with `sudo`.
- **Buildroot fails to download a package** — the container needs outbound
  network on the first build. Check that your Docker daemon has DNS
  configured correctly (`docker run --rm alpine nslookup buildroot.org`).
- **`$MCU` is empty inside the container** — something prevented
  `ACTIVATE.sh` from running. Check that `/work/ACTIVATE.sh` exists and is
  readable (`./tools/docker/run.sh ls -l ACTIVATE.sh`).
