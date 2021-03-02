FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -y devscripts debhelper

COPY src /build/src
COPY bin /build/bin
COPY debian /build/debian
COPY VERSION /build/VERSION
COPY Makefile /build/Makefile
WORKDIR /build
RUN make deb
CMD cp *.deb /out