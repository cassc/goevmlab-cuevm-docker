FROM golang:latest AS golang-builder
ENV BUILD_DATE=20241119
RUN git clone https://github.com/cassc/goevmlab --depth 1
RUN cd goevmlab && \
  go build ./cmd/generic-fuzzer && \
  go build ./cmd/checkslow && \
  go build ./cmd/minimizer && \
  go build ./cmd/repro && \
  go build ./cmd/runtest && \
  go build ./cmd/tracediff && \
  go build ./cmd/traceview
RUN git clone https://github.com/ethereum/go-ethereum --depth 1
RUN cd go-ethereum && go run build/ci.go install -static ./cmd/evm


FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# LABEL about the custom image
LABEL maintainer="dancioc@nus.edu.sg"
LABEL version="0.1"
LABEL description="This is a custom Docker Image for CuEVM project"

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive
# display
ENV DISPLAY=host.docker.internal:0.0
# timezone
ENV TZ=Asia/Singapore
# Update Ubuntu Software repository
# necasry tools curl zip unzip git wget
# gmp libgmp-dev
# cjson libcjson1 libcjson-dev
# clang
# valgrind
RUN apt-get update && apt-get upgrade -y && apt-get install -y locales && locale-gen "en_US.UTF-8" && dpkg-reconfigure locales && apt-get install -y curl zip unzip git wget libgmp-dev libcjson1 libcjson-dev libclang-dev valgrind clang-format clangd
# install rustup for REVMI
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o sh.rustup.rs && sh sh.rustup.rs -y && rm sh.rustup.rs
# install tools for documentation
RUN apt-get update && apt-get install -y doxygen sphinx cmake python3-pip && pip3 install breathe exhale sphinx_rtd_theme sphinx_book_theme
# install tools for testing
RUN apt-get update && apt-get install -y libgtest-dev
# Build GTest library
RUN cd /usr/src/googletest && \
    cmake . && \
    cmake --build . --target install

# Go-evmlab targets
RUN mkdir /goevmlab
ENV PATH="${PATH}:/goevmlab"
COPY --from=golang-builder /go/goevmlab/generic-fuzzer /goevmlab/
COPY --from=golang-builder /go/goevmlab/checkslow  /goevmlab/
COPY --from=golang-builder /go/goevmlab/minimizer /goevmlab/
COPY --from=golang-builder /go/goevmlab/repro /goevmlab/
COPY --from=golang-builder /go/goevmlab/runtest /goevmlab/
COPY --from=golang-builder /go/goevmlab/tracediff /goevmlab/
COPY --from=golang-builder /go/goevmlab/traceview /goevmlab/

COPY --from=golang-builder /go/go-ethereum/build/bin/evm /goevmlab/gethvm
