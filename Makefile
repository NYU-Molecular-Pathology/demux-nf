SHELL:=/bin/bash
PROJECT:=none
EP:=

none:

# ~~~~~ SETUP PIPELINE ~~~~~ #
./nextflow:
	module unload java && module load java/1.8 && \
	curl -fsSL get.nextflow.io | bash

install: ./nextflow



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
