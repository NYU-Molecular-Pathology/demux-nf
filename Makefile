SHELL:=/bin/bash
export NXF_VER:=0.31.1
EP:=

# no default action to take
none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
TIMESTAMP:=$(shell date +%s)
TIMESTAMP_str:=$(shell date +"%Y-%m-%d-%H-%M-%S")
DIRNAME:=$(shell python -c 'import os; print(os.path.basename(os.path.realpath(".")))')
ABSDIR:=$(shell python -c 'import os; print(os.path.realpath("."))')
HOSTNAME:=$(shell echo $$HOSTNAME)
RUNID:=
# e.g.: 180131_NB501073_0032_AHT5F3BGX3
USER_HOME=$(shell echo "$$HOME")
USER_DATE:=$(shell date +%s)

# system locations
SEQDIR:=/gpfs/data/molecpathlab/production/quicksilver
PRODDIR:=/gpfs/data/molecpathlab/production/Demultiplexing
UPLOADSDIR:=/gpfs/data/molecpathlab/production/isg-uploads

# relative locations
outputDir:=output
uploadsDir:=uploads
READS_DIR:=$(outputDir)/reads
PASSED0=$(READS_DIR)/passed0
LOGDIR:=logs
LOGDIRABS:=$(shell python -c 'import os; print(os.path.realpath("$(LOGDIR)"))')
LOGID:=$(TIMESTAMP)
LOGFILEBASE:=log.$(LOGID).out
LOGFILE:=$(LOGDIR)/$(LOGFILEBASE)
# Nextflow "publishDir" directory
publishDir:=$(outputDir)
# Nextflow "work" directory of items to be removed
workDir:=work
# Nextflow trace file
TRACEFILE:=trace.txt


# gets stuck on NFS drive and prevents install command from finishing
NXF_FRAMEWORK_DIR:=$(USER_HOME)/.nextflow/framework/$(NXF_VER)
remove-framework:
	@if [ -e "$(NXF_FRAMEWORK_DIR)" ]; then \
	new_framework="$(NXF_FRAMEWORK_DIR).$(USER_DATE)" ; \
	echo ">>> Moving old Nextflow framework dir $(NXF_FRAMEWORK_DIR) to $${new_framework}" ; \
	mv "$(NXF_FRAMEWORK_DIR)" "$${new_framework}" ; \
	fi

./nextflow:
	@[ -d "$(NXF_FRAMEWORK_DIR)" ] && $(MAKE) remove-framework || :
	@if grep -q 'phoenix' <<<'$(HOSTNAME)'; then module unload java && module load java/1.8; fi ; \
	printf ">>> Installing Nextflow in the local directory\n" && \
	curl -fsSL get.nextflow.io | bash

install: ./nextflow

check-seqdir:
	@if [ ! -d "$(SEQDIR)" ]; then printf ">>> ERROR: SEQDIR does not exist: $(SEQDIR)\n" ; exit 1; fi

check-proddir:
	@if [ ! -d "$(PRODDIR)" ]; then printf ">>> ERROR: PRODDIR does not exist: $(PRODDIR)\n"; exit 1; fi

# set up a new sequencing directory with a copy of this repo for demultiplexing
# - check that valid args were passed
# - check that sequecing dir exists
# - git clone a copy of this repo to the output production location
# - symlink the source sequecing directory to the output location
# - write the run ID to a text file in the output directory
# - copy over a supplied samplesheet to the output directory
# - if the samplesheet isn't already named SampleSheet.csv, create a symlink to it with that name
RUNDIRLINK:=runDir
RUN_ID_FILE:=runID.txt
SAMPLESHEET:=
deploy: check-seqdir check-proddir
	@[ -z "$(RUNID)" ] && printf ">>> invalid RUNID specified: $(RUNID)\n" && exit 1 || :
	@[ ! -d "$(SEQDIR)/$(RUNID)" ] && printf ">>> Project directory does not exist: $(SEQDIR)/$(RUNID)\n" && exit 1 || :
	@[ ! -d "$(SEQDIR)/$(RUNID)/Data/Intensities/BaseCalls" ] && printf ">>> Basecalls directory does not exist for run: $(SEQDIR)/$(RUNID)\n" && exit 1 || :
	@[ ! -f "$(SEQDIR)/$(RUNID)/RTAComplete.txt" ] && printf ">>> $(SEQDIR)/$(RUNID)/RTAComplete.txt does not exist, the run might not be finished yet\n" && exit 1 || :
	@[ ! -f "$(SEQDIR)/$(RUNID)/RunCompletionStatus.xml" ] && printf ">>> $(SEQDIR)/$(RUNID)/RunCompletionStatus.xml does not exist, the run might not be finished yet\n" && exit 1 || :
	@sequencing_run_results_dir="$(SEQDIR)/$(RUNID)" && \
	demultiplexing_output_dir="$(PRODDIR)/$(RUNID)" && \
	repo_dir="$${PWD}" && \
	run_id_file="$${demultiplexing_output_dir}/$(RUN_ID_FILE)" && \
	echo ">>> Setting up for demultiplexing of $(RUNID) in directory: $${demultiplexing_output_dir}" && \
	git clone --recursive "$${repo_dir}" "$${demultiplexing_output_dir}" && \
	echo ">>> Creating symlink to runDir" && \
	( cd  "$${demultiplexing_output_dir}" && ln -s "$${sequencing_run_results_dir}" "$(RUNDIRLINK)" ) && \
	if [ -n "$(SAMPLESHEET)" ]; then \
	echo ">>> Copying over samplesheet..." && \
	cp "$(SAMPLESHEET)" "$${demultiplexing_output_dir}/" ; \
	if [ "$$(basename "$(SAMPLESHEET)")" != SampleSheet.csv ]; then \
	( cd "$${demultiplexing_output_dir}" && ln -s "$$(basename $(SAMPLESHEET))" SampleSheet.csv ) ; \
	fi ; \
	fi && \
	echo ">>> Creating config file..." && \
	$(MAKE) config CONFIG_OUTPUT="$${demultiplexing_output_dir}/$(CONFIG_OUTPUT)" SAMPLESHEET="$$(basename "$(SAMPLESHEET)")" RUNDIR="$${sequencing_run_results_dir}" && \
	( cd "$${demultiplexing_output_dir}" && make fix-permissions fix-group ) && \
	echo ">>> Demultiplexing directory prepared: $${demultiplexing_output_dir}"

CONFIG_INPUT:=.config.json
CONFIG_OUTPUT:=config.json
$(CONFIG_OUTPUT):
	@echo ">>> Creating $(CONFIG_OUTPUT)" && \
	cp "$(CONFIG_INPUT)" "$(CONFIG_OUTPUT)"

RUNDIR:=
SEQTYPE:=
config: $(CONFIG_OUTPUT)
	@[ -n "$(RUNID)" ] && echo ">>> Updating runID config" && python config.py --update "$(CONFIG_OUTPUT)" --runID "$(RUNID)" || :
	@[ -n "$(SAMPLESHEET)" ] && echo ">>> Updating samplesheet config" && python config.py --update "$(CONFIG_OUTPUT)" --samplesheet "$(SAMPLESHEET)" || :
	@[ -n "$(RUNDIR)" ] && echo ">>> Updating runDir config" && python config.py --update "$(CONFIG_OUTPUT)" --runDir "$(RUNDIR)" || :
	@[ -n "$(HOSTNAME)" ] && echo ">>> Updating system config" && python config.py --update "$(CONFIG_OUTPUT)" --system "$(HOSTNAME)" || :
	@[ -n "$(SEQTYPE)" ] && echo ">>> Updating seqType config" && python config.py --update "$(CONFIG_OUTPUT)" --seqType "$(SEQTYPE)" || :
	@echo ">>> Updating demuxDir config" && python config.py --add --update "$(CONFIG_OUTPUT)" --demuxDir "$(ABSDIR)"


# denote that the run passed QC after manual review of reports
check-samplesheet:
	@if [ ! -f "$(SAMPLESHEET)" ]; then echo ">>> ERROR: samplesheet does not exist: $(SAMPLESHEET)"; exit 1 ; fi
passed: check-config-output
	@SAMPLESHEET="$$(python -c 'import json; print(json.load(open("$(CONFIG_OUTPUT)")).get("samplesheet", ""))')" && \
	$(MAKE) check-samplesheet SAMPLESHEET="$${SAMPLESHEET}" && \
	python bin/pass-run.py "$${SAMPLESHEET}"

# ~~~~~ UPDATE THIS REPO ~~~~~ #
update: pull update-submodules update-nextflow

pull: remote
	@echo ">>> Updating repo"
	@git pull

# update the repo remote for ssh
ORIGIN:=git@github.com:NYU-Molecular-Pathology/demux-nf.git
remote:
	@echo ">>> Setting git remote origin to $(ORIGIN)"
	@git remote set-url origin $(ORIGIN)

update-nextflow:
	@if [ -f nextflow ]; then \
	echo ">>> Removing old Nextflow" && \
	rm -f nextflow && \
	echo ">>> Reinstalling Nextflow" && \
	$(MAKE) install ; \
	else $(MAKE) install ; fi

# pull the latest version of all submodules
update-submodules: remote
	@echo ">>> Updating git submodules"
	@git submodule update --recursive --remote --init

# fix permissions on this directory
# make all executables group executable
# make all dirs full group accessible
# make all files group read/write
fix-permissions:
	find . -type f -executable -exec chmod ug+X {} \;
	find . -type d -exec chmod ug+rwxs {} \;
	find . -type f -exec chmod ug+rw {} \;

USERGROUP:=molecpathlab
fix-group:
	find . ! -group "$(USERGROUP)" -exec chgrp "$(USERGROUP)" {} \;

# ~~~~~ RUN PIPELINE ~~~~~ #
RESUME:=-resume
# try to detect 'run' config automatically
_RUN:=
SYSTEM:=
ifneq ($(_RUN),)
export SYSTEM:=$(shell python -c 'import json; print( json.load(open("$(CONFIG_OUTPUT)")).get("system", "None") )')
export SEQTYPE:=$(shell python -c 'import json; print( json.load(open("$(CONFIG_OUTPUT)")).get("seqType", "None") )')
endif
run:
	@echo ">>> Running with stdout log file: $(LOGFILE)" ; \
	$(MAKE) run-recurse _RUN=1 2>&1 | tee -a "$(LOGFILE)" ; \
	echo ">>> Run completed, stdout log file: $(LOGFILE)"

run-recurse:
	@echo "SYSTEM: $${SYSTEM}, SEQTYPE: $${SEQTYPE}" ; \
	if grep -q 'phoenix' <<<"$${SYSTEM}" && grep -q 'NGS580' <<<"$${SEQTYPE}" ; then echo ">>> Running run-NGS580-phoenix"; $(MAKE) run-NGS580-phoenix ; \
	elif grep -q 'phoenix' <<<"$${SYSTEM}" && grep -q 'Archer' <<<"$${SEQTYPE}" ; then echo ">>> Running run-Archer-phoenix"; $(MAKE) run-Archer-phoenix ; \
	elif grep -q 'bigpurple' <<<"$${SYSTEM}" && grep -q 'NGS580' <<<"$${SEQTYPE}" ; then echo ">>> Running run-NGS580-bigpurple"; $(MAKE) run-NGS580-bigpurple ; \
	elif grep -q 'bigpurple' <<<"$${SYSTEM}" && grep -q 'Archer' <<<"$${SEQTYPE}" ; then echo ">>> Running run-Archer-bigpurple"; $(MAKE) run-Archer-bigpurple ; \
	else echo ">>> ERROR: could not determine 'run' method to use"; exit 1; fi ; \

# methods to use for each specific profile config
run-NGS580-phoenix: install
	@if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload java && module load java/1.8 ; fi ; \
	if [ -n "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile phoenix,NGS580 --runID $(RUNID) $(EP) ; \
	elif [ -z "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile phoenix,NGS580 $(EP) ; \
	fi

run-Archer-phoenix: install
	@if [ "$$( module > /dev/null 2>&1; echo $$?)" -eq 0 ]; then module unload java && module load java/1.8 ; fi ; \
	if [ -n "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile phoenix,Archer --runID $(RUNID) $(EP) ; \
	elif [ -z "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile phoenix,Archer $(EP) ; \
	fi

run-NGS580-bigpurple: install
	if [ -n "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile bigpurple,NGS580 --runID $(RUNID) $(EP) ; \
	elif [ -z "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile bigpurple,NGS580 $(EP) ; \
	fi
# $(MAKE) perm

run-Archer-bigpurple: install
	if [ -n "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile bigpurple,Archer --runID $(RUNID) $(EP) ; \
	elif [ -z "$(RUNID)" ]; then \
	./nextflow run main.nf $(RESUME) -with-notification -with-timeline -with-trace -with-report -profile bigpurple,Archer $(EP) ; \
	fi
# $(MAKE) perm

# submit the parent Nextflow process to HPC as a cluster job
SUBJOBNAME:=demux-$(DIRNAME)
SUBLOG:=$(LOGDIRABS)/slurm-%j.$(LOGFILEBASE)
SUBQ:=intellispace
SUBTIME:=--time=2-00:00:00
SUBTHREADS:=8
SUBMEM:=64G
SUBEP:=
NXF_NODEFILE:=.nextflow.node
NXF_JOBFILE:=.nextflow.jobid
NXF_PIDFILE:=.nextflow.pid
NXF_SUBMIT:=.nextflow.submitted
NXF_SUBMITLOG:=.nextflow.submitted.log
REMOTE:=
PID:=

# check for an HPC submission lock file, then try to determine the submission recipe to use
submit:
	@if [ -e "$(NXF_SUBMIT)" ]; then echo ">>> ERROR: An instance of the pipeline has already been submitted"; exit 1 ; \
	else \
	if grep -q 'phoenix' <<<'$(HOSTNAME)'; then echo  ">>> Submission for phoenix not yet configured";  \
	elif grep -q 'bigpurple' <<<'$(HOSTNAME)'; then echo ">>> Running submit-bigpurple"; $(MAKE) submit-bigpurple ; \
	else echo ">>> ERROR: could not automatically determine 'submit' recipe to use, please consult the Makefile"; exit 1 ; fi ; \
	fi

# submit on Big Purple using SLURM
# set a submission lock file
# NOTE: Nextflow locks itself from concurrent instances but need to lock against multiple 'make submit'
submit-bigpurple:
	@touch "$(NXF_SUBMIT)" && \
	sbatch -D "$(ABSDIR)" -o "$(SUBLOG)" -J "$(SUBJOBNAME)" -p "$(SUBQ)" $(SUBTIME) --ntasks-per-node=1 -c "$(SUBTHREADS)" --mem=$(SUBMEM) --export=HOSTNAME --wrap='bash -c "make submit-bigpurple-run TIMESTAMP=$(TIMESTAMP) $(SUBEP)"' | tee >(sed 's|[^[:digit:]]*\([[:digit:]]*\).*|\1|' > '$(NXF_JOBFILE)')

# run inside a SLURM sbatch
# store old pid and node entries in a backup file in case things get messy
# need to manually set the HOSTNAME here because it changes inside SLURM job
# TODO: come up with a better method for this ^^
submit-bigpurple-run:
	if [ -e "$(NXF_NODEFILE)" -a -e "$(NXF_PIDFILE)" ]; then paste "$(NXF_NODEFILE)" "$(NXF_PIDFILE)" >> $(NXF_SUBMITLOG); fi ; \
	echo "$${SLURMD_NODENAME}" > "$(NXF_NODEFILE)" && \
	$(MAKE) run HOSTNAME="bigpurple" LOGID="$(TIMESTAMP)" EP='-bg' && \
	if [ -e "$(NXF_SUBMIT)" ]; then rm -f "$(NXF_SUBMIT)"; fi

# issue an interupt signal to a process running on a remote server
# e.g. Nextflow running in a qsub job on a compute node
kill: PID=$(shell head -1 "$(NXF_PIDFILE)")
kill: REMOTE=$(shell head -1 "$(NXF_NODEFILE)")
kill: $(NXF_NODEFILE) $(NXF_PIDFILE)
	ssh "$(REMOTE)" 'kill $(PID)'

# submit the parent Nextflow process to phoenix HPC as a qsub job
# submit-phoenix-NGS580:
# 	@qsub_logdir="logs" ; \
# 	mkdir -p "$${qsub_logdir}" ; \
# 	job_name="demux-nf" ; \
# 	echo 'make run-NGS580 EP="$(EP)" RUNID="$(RUNID)"' | qsub -wd "$$PWD" -o :$${qsub_logdir}/ -e :$${qsub_logdir}/ -j y -N "$$job_name" -q all.q
#
# submit-phoenix-Archer:
# 	@qsub_logdir="logs" ; \
# 	mkdir -p "$${qsub_logdir}" ; \
# 	job_name="demux-nf" ; \
# 	echo 'make run-Archer EP="$(EP)" RUNID="$(RUNID)"' | qsub -wd "$$PWD" -o :$${qsub_logdir}/ -e :$${qsub_logdir}/ -j y -N "$$job_name" -q all.q

# save a record of the most recent Nextflow run completion
PRE:=
RECDIR:=recorded-runs/$(PRE)demux-$(DIRNAME)_$(TIMESTAMP_str)
STDOUTLOGPATH:=
STDOUTLOG:=
ALL_LOGS:=
record: STDOUTLOGPATH=$(shell ls -d -1t $(LOGDIR)/log.*.out | head -1 | python -c 'import sys, os; print(os.path.realpath(sys.stdin.readlines()[0].strip()))' )
record: STDOUTLOG=$(shell basename "$(STDOUTLOGPATH)")
record: ALL_LOGS=$(shell find "$(LOGDIR)" -type f -name '*$(STDOUTLOG)*')
record:
	@mkdir -p "$(RECDIR)" && \
	cp -a *.html trace.txt .nextflow.log "$(RECDIR)/"&& \
	for item in $(ALL_LOGS); do cp -a "$${item}" "$(RECDIR)/"; done ; \
	echo ">>> Copied execution reports and logs to: $(RECDIR)"


# ~~~~~ DELIVERABLE ~~~~~ #
# set up a directory to organize output for delivery
# samplesheet with list of sample ID's to match amongst the .fastq.gz files; one per line
SHEET=
# identifier for the client
CLIENT=
deliverable:
	python bin/deliverable.py "$(CLIENT)" "$(SHEET)"




# ~~~~~ UPLOADS ~~~~~ #
# make a directory with renamed .fastq files compatible with Philips ISG naming scheme
# expected naming scheme: <EPIC_ID>_<Run_ID>_<Sample_ID>_<DNA_ID>_R1_001.fastq.gz
# need to strip out 'S[0-9]*_L001_' from e.g. 'S9_L001_R1_001.fastq.gz'
Passed0Fastqs:=
FindPassed0Fastq:=
ifneq ($(FindPassed0Fastq),)
Passed0Fastqs:=$(shell find "$(PASSED0)/" -maxdepth 1 -type f -name "*.fastq.gz")
endif
check-output:
	@if [ ! -d "$(outputDir)" ]; then echo ">>> ERROR: outputDir does not exist: $(outputDir)"; exit 1; fi

uploads:
uploads: uploadsPath:=$(UPLOADSDIR)/$(RUNID)/$(uploadsDir)
uploads: CONFIG_INPUT:=config.json
uploads: check-output check-passed check-runID $(PASSED0)
	mkdir -p "$(uploadsPath)" && \
	RUNID="$$(python -c 'import json; print( json.load(open("$(CONFIG_OUTPUT)")).get("runID", "None") )')"
	CONFIG_OUTPUT="$(UPLOADSDIR)/$${RUNID}/config.json" && \
	cp "$(CONFIG_INPUT)" "$${CONFIG_OUTPUT}" && \
	$(MAKE) uploads-recurse FindPassed0Fastq=1 uploadsPath="$(uploadsPath)" CONFIG_OUTPUT="$${CONFIG_OUTPUT}"
uploads-recurse: $(Passed0Fastqs) $(CONFIG_OUTPUT)
$(Passed0Fastqs):
	@newfile="$$(basename $@ | sed -e 's|\(_S[0-9]*\)\(_R[12]_001.fastq.gz\)$$|\2|')" ; \
	newpath="$(uploadsPath)/$${newfile}" ; \
	cp -via "$@" "$${newpath}"
.PHONY: $(Passed0Fastqs)

# ~~~~~ DEPLOY NGS580 ~~~~~ #
# set up a new NGS580 analysis based on this directory results; requires config file
# location of production NGS580 deployment pipeline for starting new analyses from
NGS580_PIPELINE_DIR:=/gpfs/data/molecpathlab/pipelines/NGS580-nf
check-NGS580_PIPELINE_DIR:
	@if [ ! -d "$(NGS580_PIPELINE_DIR)" ]; then echo ">>> ERROR: NGS580_PIPELINE_DIR does not exist: $(NGS580_PIPELINE_DIR)"; exit 1; fi
check-config-output:
	@if [ ! -f "$(CONFIG_OUTPUT)" ]; then echo ">>> ERROR: config file does not exist: $(CONFIG_OUTPUT)"; exit 1 ; fi
check-runID:
	@if [ -z "$(RUNID)" ]; then echo ">>> ERROR: invalid RUNID value: $(RUNID)"; exit 1; fi
	@if [ "$(RUNID)" == "None" ]; then printf ">>> ERROR: RUNID is 'None', please specify a different RUNID"; exit 1; fi
check-passed:
	@if [ ! -e "$(PASSED0)" ]; then echo ">>> ERROR: 'passed0' does not exist: $(PASSED0); Was this run checked & passed?"; exit 1; fi

deploy-NGS580: FASTQDIR:=$(PASSED0)
deploy-NGS580: check-NGS580_PIPELINE_DIR check-config-output check-passed
	RUNID="$$(python -c 'import json; print(json.load(open("$(CONFIG_OUTPUT)")).get("runID", ""))')" && \
	FASTQDIR="$$(python -c 'import os; print(os.path.realpath("$(FASTQDIR)"))')" && \
	SAMPLESHEET="$$(python -c 'import json, os; print(os.path.realpath(json.load(open("$(CONFIG_OUTPUT)")).get("samplesheet", "")))')" && \
	$(MAKE) check-runID RUNID="$${RUNID}" && \
	cd "$(NGS580_PIPELINE_DIR)" && \
	make deploy FASTQDIR="$${FASTQDIR}" RUNID="$${RUNID}" DEMUX_SAMPLESHEET="$${SAMPLESHEET}"



# ~~~~~ FINALIZE ~~~~~ #
# steps for finalizing the Nextflow pipeline 'output' publishDir and 'work' directories
# configured for parallel processing with `make finalize -j8`

# remove extraneous work dirs
# resolve publishDir output symlinks
# write work 'ls' files
# create work dir file stubs
finalize:
	$(MAKE) finalize-work-rm
	$(MAKE) finalize-output
	$(MAKE) finalize-work-ls
	$(MAKE) finalize-work-stubs

## ~~~ convert all symlinks to their linked items ~~~ ##
# symlinks in the publishDir to convert to files
publishDirLinks:=
FIND_publishDirLinks:=
ifneq ($(FIND_publishDirLinks),)
publishDirLinks:=$(shell find $(publishDir)/ -type l)
endif
finalize-output:
	@echo ">>> Converting symlinks in output dir '$(publishDir)' to their targets..."
	$(MAKE) finalize-output-recurse FIND_publishDirLinks=1
finalize-output-recurse: $(publishDirLinks)
# convert all symlinks to their linked items
$(publishDirLinks):
	@ { \
	destination="$@"; \
	sourcepath="$$(python -c 'import os; print(os.path.realpath("$@"))')" ; \
	echo ">>> Resolving path: $${destination}" ; \
	if [ ! -e "$${sourcepath}" ]; then echo "ERROR: Source does not exist: $${sourcepath}"; \
	elif [ -f "$${sourcepath}" ]; then rsync -va "$$sourcepath" "$$destination" ; \
	elif [ -d "$${sourcepath}" ]; then { \
	timestamp="$$(date +%s)" ; \
	tmpdir="$${destination}.$${timestamp}" ; \
	rsync -va "$${sourcepath}/" "$${tmpdir}" && \
	rm -f "$${destination}" && \
	mv "$${tmpdir}" "$${destination}" ; } ; \
	fi ; }
.PHONY: $(publishDirLinks)


## ~~~ write list of files in each subdir to file '.ls.txt' ~~~ ##
# subdirs in the 'work' dir
NXFWORKSUBDIRS:=
FIND_NXFWORKSUBDIRS:=
ifneq ($(FIND_NXFWORKSUBDIRS),)
NXFWORKSUBDIRS:=$(shell find "$(workDir)/" -maxdepth 2 -mindepth 2)
endif
# file to write 'ls' contents of 'work' subdirs to
LSFILE:=.ls.txt
finalize-work-ls:
	@echo ">>> Writing list of directory contents for each subdir in Nextflow work directory '$(workDir)'..."
	$(MAKE) finalize-work-ls-recurse FIND_NXFWORKSUBDIRS=1
finalize-work-ls-recurse: $(NXFWORKSUBDIRS)
# print the 'ls' contents of each subdir to a file, or delete the subdir
$(NXFWORKSUBDIRS):
	@ls_file="$@/$(LSFILE)" ; \
	echo ">>> Writing file list: $${ls_file}" ; \
	ls -1 "$@" > "$${ls_file}"
.PHONY: $(NXFWORKSUBDIRS)


## ~~~ replace all files in 'work' dirs with empty file stubs ~~~ ##
NXFWORKFILES:=
FIND_NXFWORKFILES:=
# files in work subdirs to keep
LSFILEREGEX:=\.ls\.txt
NXFWORKFILES:='.command.begin|.command.err|.command.log|.command.out|.command.run|.command.sh|.command.stub|.command.trace|.exitcode|$(LSFILE)'
NXFWORKFILESREGEX:='.*\.command\.begin\|.*\.command\.err\|.*\.command\.log\|.*\.command\.out\|.*\.command\.run\|.*\.command\.sh\|.*\.command\.stub\|.*\.command\.trace\|.*\.exitcode\|.*$(LSFILEREGEX)'
ifneq ($(FIND_NXFWORKFILES),)
NXFWORKFILES:=$(shell find -P "$(workDir)/" -type f ! -regex $(NXFWORKFILESREGEX))
endif
finalize-work-stubs:
	@echo ">>> Creating file stubs for pipeline output in Nextflow work directory '$(workDir)'..."
	$(MAKE) finalize-work-stubs-recurse FIND_NXFWORKFILES=1
finalize-work-stubs-recurse: $(NXFWORKFILES)
$(NXFWORKFILES):
	@printf '>>> Creating file stub: $@\n' && rm -f "$@" && touch "$@"
.PHONY: $(NXFWORKFILES)


## ~~~ remove 'work' subdirs that are not in the latest trace file (e.g. most previous run) ~~~ ##
# subdirs in the 'work' dir
NXFWORKSUBDIRSRM:=
FIND_NXFWORKSUBDIRSRM:=
# regex from the hashes of tasks in the tracefile to match against work subdirs
HASHPATTERN:=
ifneq ($(FIND_NXFWORKSUBDIRSRM),)
NXFWORKSUBDIRSRM:=$(shell find "$(workDir)/" -maxdepth 2 -mindepth 2)
HASHPATTERN:=$(shell python -c 'import csv; reader = csv.DictReader(open("$(TRACEFILE)"), delimiter = "\t"); print("|".join([row["hash"] for row in reader]))')
endif
finalize-work-rm:
	@echo ">>> Removing subdirs in Nextflow work directory '$(workDir)' which are not included in Nextflow trace file '$(TRACEFILE)'..."
	$(MAKE) finalize-work-rm-recurse FIND_NXFWORKSUBDIRSRM=1
finalize-work-rm-recurse: $(NXFWORKSUBDIRSRM)
# remove the subdir if its not listed in the trace hashes
$(NXFWORKSUBDIRSRM):
	@if [ ! "$$(echo '$@' | grep -q -E "$(HASHPATTERN)"; echo $$? )" -eq 0 ]; then \
	echo ">>> Removing subdir: $@" ; \
	rm -rf "$@" ; \
	fi
.PHONY: $(NXFWORKSUBDIRSRM)


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
