# Reproducible build environment for the Emcraft Linux-CM BSP -- uClinux for
# the NXP i.MX RT family.
#
# This image bakes in the host build dependencies needed to build the kernel,
# U-Boot, buildroot, and project apps. The release tree (including the
# cross-toolchain under tools/ and the prebuilt utilities under tools/bin/) is
# bind-mounted at /work at run time, so the same image works for any customer
# checkout of a matching release.
#
# Build via tools/docker/run.sh --build (or implicitly on first run).

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# i386 multilib is required to execute the bind-mounted 32-bit ELF utilities
# under /work/tools/bin/ (mkimage, fdpichdr).
RUN dpkg --add-architecture i386

# Host build deps for kernel 6.12, U-Boot 2025.04, buildroot, and rfs-builder.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        libc6:i386 \
        bc \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        device-tree-compiler \
        file \
        findutils \
        flex \
        gawk \
        gettext \
        git \
        gzip \
        kmod \
        libelf-dev \
        libgmp-dev \
        libmpc-dev \
        libncurses-dev \
        libssl-dev \
        libtool-bin \
        locales \
        make \
        nano \
        patch \
        perl \
        pkg-config \
        python3 \
        python3-dev \
        python3-setuptools \
        rsync \
        sed \
        sudo \
        swig \
        tar \
        texinfo \
        unzip \
        vim-tiny \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV EDITOR=nano

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Optional in-container installer support. Off by default. Enable at image
# build time via:
#   WITH_INSTALLER=1 ./tools/docker/run.sh --build
#
# When on, the layer pulls in the SPSDK CLI (blhost / sdphost) plus the
# host-side libs SPSDK needs to talk to USB (libusb / libhidapi / libftdi1)
# so imxrt_install.sh works inside the container. blhost covers RT1170 and
# sdphost covers RT1050 / RT1060. Installed into /opt/spsdk-venv to avoid
# PEP 668 conflicts with the system Python; imxrt_install.sh resolves them
# via PATH thanks to its hardcoded-NXP-vendor-path fallback.
ARG WITH_INSTALLER=0
RUN if [ "$WITH_INSTALLER" = "1" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            libusb-1.0-0 libhidapi-libusb0 libftdi1-2 python3-venv && \
        rm -rf /var/lib/apt/lists/* && \
        python3 -m venv /opt/spsdk-venv && \
        /opt/spsdk-venv/bin/pip install --no-cache-dir --upgrade pip && \
        /opt/spsdk-venv/bin/pip install --no-cache-dir spsdk==3.8.0 && \
        ln -s /opt/spsdk-venv/bin/blhost  /usr/local/bin/blhost  && \
        ln -s /opt/spsdk-venv/bin/sdphost /usr/local/bin/sdphost ; \
    fi

# Interactive prompt: drop the noisy "ubuntu@<container-id>" prefix and show
# the active MCU (set by ACTIVATE.sh) in green, followed by cwd.
# Single quotes are deliberate -- $MCU must be expanded at prompt render time,
# not when the rc file is read. Appended to multiple rc files because bash
# sources them in order (/etc/bash.bashrc, then ~/.bashrc) and the last
# assignment wins; on Ubuntu 24.04 the pre-existing ubuntu user's ~/.bashrc
# re-sets PS1, so we override it there too. /etc/skel/.bashrc covers any
# new user the entrypoint creates for non-1000 UIDs.
RUN PS1_LINE='PS1='"'"'\[\e[1;32m\][${MCU:-no-mcu}]\[\e[0m\] \w\$ '"'"'' && \
    for f in /etc/bash.bashrc /etc/skel/.bashrc /home/ubuntu/.bashrc; do \
        [ -f "$f" ] && printf '\n# Emcraft Linux-CM build container prompt\n%s\n' "$PS1_LINE" >> "$f"; \
    done

# Suppress the Ubuntu "To run a command as administrator (user root) ..."
# sudo hint that /etc/bash.bashrc prints in interactive shells. The hint is
# gated on $HOME/.hushlogin not existing, so dropping the file in skel and
# in the pre-existing ubuntu user's home is enough to silence it everywhere.
RUN touch /etc/skel/.hushlogin /home/ubuntu/.hushlogin && \
    chown ubuntu:ubuntu /home/ubuntu/.hushlogin

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
