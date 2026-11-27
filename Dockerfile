# Zlyme build container. Pinned by digest.

FROM debian:trixie-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash bc binutils build-essential bzip2 ca-certificates cpio \
      file findutils git gzip libncurses-dev locales make patch perl \
      python3 python3-dev \
      python3-pil=11.1.0-5+deb13u4 \
      librsvg2-bin=2.60.0+dfsg-1+deb13u1 \
      rsync sed shellcheck tar unzip wget which xz-utils \
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
