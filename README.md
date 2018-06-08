# demux-nf
Nextflow pipeline for demultiplexing.

# Installation

Clone this repository:

```
git clone --recursive https://github.com/NYU-Molecular-Pathology/demux-nf.git
cd demux-nf
```
# Usage

The pipeline is run with Nextflow from the `main.nf` file. Example:

```
nextflow run main.nf
```

Many pipeline configuration settings are available and required. The easiest way to run the pipeline is by using the included `Makefile`, which has shortcuts to preset execution configurations, with the sequencer output directory name provided as an argument to `RUNID`. Extra parameters for Nextflow can be provided with `EP`.

_NOTE:_ By default, the pipeline will run in the _current session_ in your terminal. To run the pipeline in the background, it is recommended to either run it in `screen` or submit it as a job on the HPC.

## NYU phoenix HPC cluster

The default configuration is set up for usage on NYU's phoenix HPC cluster. Relevant settings for this can be overriden in the `Makefile` and `nextflow.config` files.

### Setup a new run for demultiplexing

The `deploy` recipe can be used to set up a new directory for demultiplexing:

```
make deploy RUNID=<run ID>
```

where `RUNID` is the name of the directory output by the sequencer. 

Example:

```
make deploy RUNID=180122_NB501073_0030_AHTCJTBGX3
```

This will:

- check for a matching sequencing run directory in the path specified by the `SEQDIR` variable in the Makefile

- create a new output directory for the given run in the path specificed by the `PRODDIR` variable in the Makefile

- clone this repo to that location

### NGS580 Demultiplexing on NYU phoenix

```
make run-NGS580 RUNID=<run ID>
```

- Example:

```
make run-NGS580 RUNID=180316_NB501073_0036_AH3VFKBGX5
```

with extra parameters:

```
make run-NGS580 RUNID=180316_NB501073_0036_AH3VFKBGX5 EP="--samplesheet SampleSheet.csv --run_dir /data/180316_NB501073_0036_AH3VFKBGX5"
```

#### HPC Cluster submission script

The parent Nextflow process can be submitted to run as a `qsub` job with the `submit-phoenix-NGS580` Makefile recipe. Example: 

```
make submit-phoenix-NGS580 RUNID=180316_NB501073_0036_AH3VFKBGX5 EP='--samplesheet SampleSheet.csv --run_dir /data/180316_NB501073_0036_AH3VFKBGX5'
```

_NOTE:_ This only runs the parent Nextflow process as a cluster job; Nextflow already submits its processes as cluster jobs themselves as per configurations. 

# Software Requirements

- Java 8 (Nextflow)

- `bcl2fastq` version 2.17.1

- FastQC version 0.11.7

- R (3.3.0+ recommended, with `knitr` and `rmarkdown` installed)

- Pandoc 1.13.1+

- GraphViz Dot (to compile flowchart)

