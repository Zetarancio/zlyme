# Zlyme build container. Pinned by digest.

FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash bc binutils build-essential bzip2 ca-certificates cpio \
      file findutils git gzip libncurses-dev locales make patch perl \
      python3 python3-dev rsync sed tar unzip wget which xz-utils \
      ccache \
      device-tree-compiler \
      dosfstools mtools parted \
      libssl-dev \
      gawk diffutils \
      graphviz python3-matplotlib \
      ruby autoconf automake libtool zip universal-ctags bison flex curl \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i '/^# *en_US.UTF-8 /s/^# *//' /etc/locale.gen && locale-gen
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

WORKDIR /zlyme
