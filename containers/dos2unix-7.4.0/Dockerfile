FROM ubuntu:16.04
RUN apt-get update && \
apt-get install -y \
wget \
make \
gcc \
gettext

RUN cd /opt/ && \
wget https://managedway.dl.sourceforge.net/project/dos2unix/dos2unix/7.4.0/dos2unix-7.4.0.tar.gz && \
tar -xzf dos2unix-7.4.0.tar.gz && \
rm -f dos2unix-7.4.0.tar.gz && \
cd dos2unix-7.4.0 && \
make

ENV PATH="/opt/dos2unix-7.4.0:$PATH"
ENV LC_ALL="C.UTF-8"
ENV LANG="C.UTF-8"
