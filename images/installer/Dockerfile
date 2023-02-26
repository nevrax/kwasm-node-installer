FROM ubuntu:18.04 as builder-crun

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl make git gcc build-essential pkgconf libtool libsystemd-dev libprotobuf-c-dev libcap-dev libseccomp-dev libyajl-dev go-md2man libtool autoconf python3 automake xz-utils \
    && curl https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- -p /usr/local --version=0.11.0 \
    && git clone --depth 1 --branch 1.6 https://github.com/containers/crun.git \
    && cd crun \
    && ./autogen.sh \
    && ./configure --with-wasmedge --enable-embedded-yajl\
    && make \
    && mv crun crun-wasmedge
RUN curl -L https://github.com/bytecodealliance/wasmtime/releases/download/v1.0.1/wasmtime-v1.0.1-$(uname -m)-linux-c-api.tar.xz | tar xJf - -C / \
    && cp -R /wasmtime-v1.0.1-$(uname -m)-linux-c-api/* /usr/local/ \
    && cd /crun \
    && ./configure --with-wasmtime --enable-embedded-yajl \
    && make \
    && mv crun crun-wasmtime

FROM ubuntu:18.04 as builder-containerd-shim

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl
RUN curl -L https://github.com/deislabs/containerd-wasm-shims/releases/download/v0.4.0/containerd-wasm-shims-v1-linux-$(uname -m).tar.gz | tar -xzf - 
    # && curl -L https://github.com/second-state/runwasi/releases/download/v0.3.2/containerd-shim-wasmedge-v1-v0.3.2-linux-$(uname -m | sed s/aarch64/arm64/g | sed s/x86_64/amd64/g).tar.gz | tar -xzf -

FROM ubuntu:18.04 as builder-containerd-shim-wasmedge

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y git curl libclang-dev python3 \
    && curl https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash \
    && echo "$HOME/.wasmedge/lib" > /etc/ld.so.conf.d/libwasmedge.conf \
    && ldconfig \
    && git clone --depth 1 --branch fix-stale-shim https://github.com/0xE282B0/runwasi.git
WORKDIR /runwasi
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup && chmod +x ./rustup \
    && ./rustup -y 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y make build-essential clang \
    && bash -c "source ~/.cargo/env && rustup default nightly && make build FEATURES=wasmedge"

FROM ubuntu:18.04 as builder-curl

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl \
    && curl -LO https://github.com/moparisthebest/static-curl/releases/download/v7.87.0/curl-$(uname -m | sed s/x86_64/amd64/g) \
    && chmod +x /curl*

FROM golang:1.20 as builder-cri-dockerd

WORKDIR /
RUN git clone --depth 1 --branch kwasm https://github.com/KWasm/cri-dockerd.git \
    && cd cri-dockerd \
    && go build -o bin/cri-dockerd

FROM busybox as crun-wasmtime

COPY --link --from=builder-crun /crun/crun-wasmtime /assets/crun-wasmtime
COPY --link --from=builder-crun /usr/local/lib/libwasmtime.so /assets/libwasmtime.so
COPY script/installer.sh /script/installer.sh

CMD sh /script/installer.sh wasmtime

FROM busybox as crun-wasmedge

COPY --link --from=builder-crun /crun/crun-wasmedge /assets/crun-wasmedge
COPY --link --from=builder-crun /usr/local/lib/libwasmedge.so /assets/libwasmedge.so
COPY script/installer.sh /script/installer.sh

CMD sh /script/installer.sh wasmedge

FROM busybox

COPY script/installer.sh /script/installer.sh
COPY script/docker-desktop.sh /script/docker-desktop.sh
COPY --link --from=builder-crun /crun/crun-* /assets/
COPY --link --from=builder-crun /usr/local/lib/libwasmedge.so /assets/libwasmedge.so
COPY --link --from=builder-crun /usr/local/lib/libwasmtime.so /assets/libwasmtime.so
COPY --link --from=builder-containerd-shim /containerd-shim-slight-v1 /assets/containerd-shim-slight-v1
COPY --link --from=builder-containerd-shim /containerd-shim-spin-v1 /assets/containerd-shim-spin-v1
COPY --link --from=builder-containerd-shim-wasmedge /runwasi/target/debug/containerd-shim-wasmedge-v1 /assets/containerd-shim-wasmedge-v1
COPY --link --from=builder-cri-dockerd /cri-dockerd/bin/cri-dockerd /assets/cri-dockerd
COPY --link --from=builder-curl /curl* /assets/curl

CMD sh /script/installer.sh wasmedge