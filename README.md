# demux-nf

Nextflow pipeline for demultiplexing Illumina Next-Gen sequencing data.

# Usage

Clone this repository:

```
git clone --recursive https://github.com/NYU-Molecular-Pathology/demux-nf.git
```

## Deployment

The included `deploy` recipe should be used to create a new directory for demultiplexing based on a currently existing sequencing run directory. Include arguments that describe the configuration for your sequencing run.

```
cd demux-nf
make deploy RUNID=170809_NB501073_0019_AH5FFYBGX3 SAMPLESHEET=SampleSheet.csv SEQTYPE=Archer
```

arguments:

  - `RUNID`: the identifier given to the run by the sequencer
  
  - `SAMPLESHEET`: the samplesheet required for demultiplexing with `bcl2fastq`
  
  - `SEQTYPE`: the type of sequencing; currently only `Archer` or `NGS580` are used
  
  - `SEQDIR`: parent directory where the sequencer outputs its data (pre-configured for NYU server locations)
  
  - `PRODDIR`: parent directory where demultiplexing output should be stored (pre-configured for NYU server locations)
  

This will first check that the specified run exists on the server before cloning into a new directory at the given production output location and configuring it for demultiplexing using the subsequent commands described here. 

## Run Workflow

Assuming you used `make deploy` or `make config` to prepare your demultiplexing directory, the following command can be used to automatically run the workflow based on the pre-defined settings and settings from your current system.

```
make run
```

Extra parameters to be passed to Nextflow can be supplied with the `EP` argument:

```
make run EP='--samplesheet SampleSheet.csv --runDir /path/to/sequencer/data/170809_NB501073_0019_AH5FFYBGX3'
```

For alternative `run` methods, consult the `Makefile`.

# Configuration

Demultiplexing metadata for the workflow can be provided through several methods, evaluated in the following order:

- parameters can be supplied directly to Nextflow via CLI

```
nextflow run main.nf --runID 12345
```

- if the file `config.json` is present, non-`null` parameters will be retrieved

```
{
    "runDir": "/path/to/sequencer/data/170809_NB501073_0019_AH5FFYBGX3",
    "samplesheet": "SampleSheet.csv",
    "runID": "170809_NB501073_0019_AH5FFYBGX3"
}
```

  - this file is generated automatically during the `deploy` step, using the included `config.py` script

- the following items in the current directory will be used if present:

  - `SampleSheet.csv`: default samplesheet file

  - `runDir` : default sequencing run source directory (can be a symlink)
  
  - `runID.txt`: a text file, the first line of which will be used as the run ID

# Extras

- (re)initialize configurations (overwrites old `config.json`):

```
make config RUNDIR=/path/to/sequencer/data/170809_NB501073_0019_AH5FFYBGX3 SAMPLESHEET=SampleSheet.csv RUNID=170809_NB501073_0019_AH5FFYBGX3
```

- update an existing directory to the latest version of this repo:

```
make update
```

- clean up workflow intermediary files to save space (workflow cannot be resumed after this):

```
make finalize
```

- clean up output from all old workflows (saves current workflow output):

```
make clean
```

- delete the output from all workflows:

```
make clean-all
```

- mark that the demultiplexing suceeded and the results passed QC for downstream analysis:

```
make passed
```

- deploy a new NGS580 analysis using the current results:

```
make deploy-NGS580
```

- make a 'deliverables' directory with just the results for samples for a specific client

```
make deliverable CLIENT=somelab SHEET=list_of_clients_samples.txt
```

# Software 

Required:

- Java 8 (Nextflow)

- Python 2.7+

- GNU `make`

Optional; must be installed to system or available with Singularity containers:

- `bcl2fastq` version 2.17.1

- FastQC version 0.11.7

- R (3.3.0+, with `knitr` and `rmarkdown` libraries)

- Pandoc 1.13.1+
