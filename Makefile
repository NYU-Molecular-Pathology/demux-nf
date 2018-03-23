SHELL:=/bin/bash
PROJECT:=none
SEQDIR:=/ifs/data/molecpathlab/quicksilver
EP:=

none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	module unload java && module load java/1.8 && \
	curl -fsSL get.nextflow.io | bash

install: ./nextflow

# set up a new sequencing directory with a copy of this repo for demultiplexing
deploy:
	[ -z "$(PROJECT)" ] && printf "invalid PROJECT specified: $(PROJECT)\n" && exit 1 || :
	[ ! -d "$(SEQDIR)/$(PROJECT)" ] && printf "invalid PROJECT specified: $(PROJECT)\n" && exit 1 || :
	[ ! -d "$(SEQDIR)/$(PROJECT)/Data/Intensities/BaseCalls" ] && printf "Basecalls directory does not exist for run: $(SEQDIR)/$(PROJECT)\n" && exit 1 || :
	basecalls_dir="$(SEQDIR)/$(PROJECT)/Data/Intensities/BaseCalls" && \
	echo "Setting up for demultiplexing in directory: $${basecalls_dir}" && \
	repo_dir="$${PWD}" && \
	cd "$${basecalls_dir}" && \
	git clone $${repo_dir} && \
	run_cmd="make run-NGS580 PROJECT=$(PROJECT)" && \
	output_dir="$${basecalls_dir}/$$(basename $${repo_dir})" && \
	printf "please run the following command to start demultiplexing:\n\n%s\n%s\n" "cd $${output_dir}" "$${run_cmd}" 


# ~~~~~ RUN PIPELINE ~~~~~ #
run-NGS580: install
	module unload java && module load java/1.8 && \
	./nextflow run main.nf -profile phoenix,NGS580 --project $(PROJECT) $(EP)




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

# deletes all pipeline output
clean-all: clean clean-output clean-work 
	[ -d .nextflow ] && mv .nextflow .nextflowold && rm -rf .nextflowold &
	rm -f .nextflow.log
	rm -f *.png
	rm -f trace*.txt*
	rm -f *.html*
