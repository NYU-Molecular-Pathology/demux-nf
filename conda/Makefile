SHELL:=/bin/bash
CONDA:=/ifs/data/molecpathlab/bin/conda3
VAR:=

# ~~~~~~ INSTALL CONDA ~~~~~~ #
MINICONDA_sh:=Miniconda3-4.5.1-Linux-x86_64.sh
MINICONDA_sh_url:=https://repo.continuum.io/miniconda/$(MINICONDA_sh)
MINICONDA_sh_md5:=454e3b786937eeaa50fb7bee991ac19e
CONDA_ACTIVATE:=$(CONDA)/bin/activate
.INTERMEDIATE: $(MINICONDA_sh)

$(MINICONDA_sh):
	wget "$(MINICONDA_sh_url)"


dl: $(MINICONDA_sh)

$(CONDA): dl
	@if [ ! -d "$(CONDA)" ]; then \
	bash "$(MINICONDA_sh)" -b -p "$(CONDA)"; \
	else \
	printf "Install dir already exists: %s\nExiting..." "$(CONDA)"; \
	exit 1; fi


# install conda in the current directory and install the conda-build package to it
install: $(CONDA)
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload python; fi ; \
	if [ ! -z ${PYTHONPATH+x} ]; then unset PYTHONPATH; fi ; \
	if [ ! -z ${PYTHONHOME+x} ]; then unset PYTHONHOME; fi ; \
	source "$(CONDA_ACTIVATE)" && \
	conda install -y conda-build && \
	conda config --add channels defaults && \
	conda config --add channels conda-forge && \
	conda config --add channels bioconda




# ~~~~~ CREATE ENV ~~~~~ #
# `make create VAR=<somedir>`
check: 
	@if [ ! -d "$(VAR)" ]; then echo "ERROR: VAR is not a valid directory; VAR=$(VAR)"; exit 1; fi

# standard env build methods
create: check
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload python; fi ; \
	if [ ! -z ${PYTHONPATH+x} ]; then unset PYTHONPATH; fi ; \
	if [ ! -z ${PYTHONHOME+x} ]; then unset PYTHONHOME; fi ; \
	source "$(CONDA_ACTIVATE)" && \
	conda env create --file "$(VAR)/env.yml" --name "$(VAR)"

remove:
	source "$(CONDA)/bin/activate" && \
	conda env remove -n "$(VAR)"

# ~~~~~ BUILD CONDA PACKAGE ~~~~~ #
build-bcl2fastq-2.17.1:
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload python; fi ; \
	if [ ! -z ${PYTHONPATH+x} ]; then unset PYTHONPATH; fi ; \
	if [ ! -z ${PYTHONHOME+x} ]; then unset PYTHONHOME; fi ; \
	source "$(CONDA_ACTIVATE)" && \
	conda-build -c dranew "bcl2fastq-2.17.1" && \
	conda create -y -c local -n "bcl2fastq-2.17.1" bcl2fastq==2.17.1