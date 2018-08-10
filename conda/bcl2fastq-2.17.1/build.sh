#!/bin/bash

CC=${PREFIX}/bin/gcc
CXX=${PREFIX}/bin/g++
wget ftp://webdata2:webdata2@ussd-ftp.illumina.com/downloads/software/bcl2fastq/bcl2fastq2-v2.17.1.14.tar.zip
unzip bcl2fastq2-v2.17.1.14.tar.zip
gunzip bcl2fastq2-v2.17.1.14.tar.gz
tar -xf bcl2fastq2-v2.17.1.14.tar

cd bcl2fastq
mkdir build
cd build
../src/configure --prefix=$PREFIX

make
make install
