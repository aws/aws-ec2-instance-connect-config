FROM amazonlinux:2.0.20180622.1
RUN yum install -y rpmbuild rpmdevtools make --skip-broken

COPY src /build/src
COPY bin /build/bin
COPY rpmsrc /build/rpmsrc
COPY VERSION /build/VERSION
COPY Makefile /build/Makefile
WORKDIR /build
RUN make rpm
CMD cp *.rpm /out