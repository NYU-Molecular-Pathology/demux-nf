SHELL:=/bin/bash
PROJECT:=
SEQDIR:=/ifs/data/molecpathlab/quicksilver
PRODDIR:=/ifs/data/molecpathlab/production/Demultiplexing
NXF_VER:=0.29.0
EP:=

none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload java && module load java/1.8 ; fi ; \
	export NXF_VER="$(NXF_VER)" && \
	printf ">>> Intalling Nextflow in the local directory" && \
	curl -fsSL get.nextflow.io | bash

install: ./nextflow

check-seqdir:
	@if [ ! -d "$(SEQDIR)" ]; then printf ">>> ERROR: SEQDIR does not exist: $(SEQDIR)\n" ; exit 1; fi

check-proddir:
	@if [ ! -d "$(PRODDIR)" ]; then printf ">>> ERROR: PRODDIR does not exist: $(PRODDIR)\n"; exit 1; fi

# set up a new sequencing directory with a copy of this repo for demultiplexing
deploy: check-seqdir check-proddir
	@[ -z "$(PROJECT)" ] && printf ">>> invalid PROJECT specified: $(PROJECT)\n" && exit 1 || :
	@[ ! -d "$(SEQDIR)/$(PROJECT)" ] && printf ">>> Project directory does not exist: $(SEQDIR)/$(PROJECT)\n" && exit 1 || :
	@[ ! -d "$(SEQDIR)/$(PROJECT)/Data/Intensities/BaseCalls" ] && printf ">>> Basecalls directory does not exist for run: $(SEQDIR)/$(PROJECT)\n" && exit 1 || :
	@project_dir="$(SEQDIR)/$(PROJECT)" && \
	production_dir="$(PRODDIR)/$(PROJECT)" && \
	repo_dir="$${PWD}" && \
	output_dir="$${production_dir}/$$(basename $${repo_dir})" && \
	echo ">>> Setting up for demultiplexing of $(PROJECT) in directory: $${production_dir}" && \
	git clone --recursive "$${repo_dir}" "$${production_dir}" && \
	( cd  "$${production_dir}" && ln -s "$${project_dir}" seq_dir ) && \
	echo ">>> Demultiplexing directory prepared: $${production_dir}"

# update the repo remote for ssh
remote:
	git remote set-url origin git@github.com:NYU-Molecular-Pathology/demux-nf.git

# pull the latest version of all submodules
# https://stackoverflow.com/a/1032653/5359531
update-submodules: remote
	git submodule update --recursive --remote --init

# ~~~~~ RUN PIPELINE ~~~~~ #
run-NGS580: install
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload java && module load java/1.8 ; fi ; \
	if [ -n "$(PROJECT)" ]; then \
	./nextflow run main.nf -resume -profile phoenix,NGS580 --projectID $(PROJECT) $(EP) && \
	./nextflow run email.nf -profile phoenix,NGS580 --project $(PROJECT) $(EP) ; \
	elif [ -z "$(PROJECT)" ]; then \
	./nextflow run main.nf -resume -profile phoenix,NGS580 $(EP) && \
	./nextflow run email.nf -profile phoenix,NGS580 --project $(PROJECT) $(EP) ; \
	fi


run-Archer: install
	if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload java && module load java/1.8 ; fi ; \
	./nextflow run main.nf -profile phoenix,Archer --projectID $(PROJECT) $(EP) && \
	./nextflow run email.nf -profile phoenix,NGS580 --project $(PROJECT) $(EP)


# submit the parent Nextflow process to phoenix HPC as a qsub job
submit-phoenix-NGS580:
	@qsub_logdir="logs" ; \
	mkdir -p "$${qsub_logdir}" ; \
	job_name="demux-nf" ; \
	echo 'make run-NGS580 EP="$(EP)" PROJECT="$(PROJECT)"' | qsub -wd "$$PWD" -o :$${qsub_logdir}/ -e :$${qsub_logdir}/ -j y -N "$$job_name" -q all.q 

# ~~~~~ CLEANUP ~~~~~ #
clean-traces:
	rm -f trace*.txt.*

clean-logs:
	rm -f .nextflow.log.*

clean-reports:
	rm -f *.html.*

clean-flowcharts:
	rm -f *.dot.*

clean-output:
	[ -d output ] && mv output oldoutput && rm -rf oldoutput &	

clean-work:
	[ -d work ] && mv work oldwork && rm -rf oldwork &

# deletes files from previous runs of the pipeline, keeps current results
clean: clean-logs clean-traces clean-reports clean-flowcharts

# deletes all pipeline output in current directory
clean-all: clean clean-output clean-work 
	[ -d .nextflow ] && mv .nextflow .nextflowold && rm -rf .nextflowold &
	rm -f .nextflow.log
	rm -f *.png
	rm -f trace*.txt*
	rm -f *.html*

# deletes all pipeline output along with 'output' directory one level up
clean-results: clean-all
	[ -d ../output ] && mv ../output ../output_old && rm -rf ../output_old &
