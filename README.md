# demux-nf

Nextflow pipeline for demultiplexing Illumina Next-Gen sequencing data.

# Usage

Clone this repository:

```
git clone --recursive https://github.com/NYU-Molecular-Pathology/demux-nf.git
```

## Deployment

It is recommended to use the included `deploy` feature to create a new directory for demultiplexing based on a currently existing sequencing run directory.

```
cd demux-nf
make deploy SEQDIR=/path/to/sequencer/data PRODDIR=/path/to/demultiplexing/output
```

- `SEQDIR` and `PRODDIR` come already hard-coded for NYU server locations

Its also a good idea to include parameters about the run which you are preparing to demultiplexing.

```
make deploy RUNID=170809_NB501073_0019_AH5FFYBGX3 SAMPLESHEET=/path/to/sequencer/data/170809_NB501073_0019_AH5FFYBGX3/Data/Intensities/BaseCalls/SampleSheet.csv
```

This will clone into a new directory and configure it to demultiplex the specified sequencing run, making it easier to run subsequent commands.

## Run Workflow

It is recommended to run the workflow using the included configuration settings and command shortcuts contained in the `Makefile`. Run the workflow from the directory created with `make deploy`, or one you cloned & configured yourself.

### NGS580

To run the included NGS580 panel demultiplexing workflow, simply use:

```
make run-NGS580
```
- if `config.json` is present, it will be examined for run ID, run directory location, and samplesheet file location

- alternatively, these options can be supplied via the `Makefile` and extra Nextflow parameters:


```
make run-NGS580 RUNID=180316_NB501073_0036_AH3VFKBGX5 EP="--samplesheet SampleSheet.csv --run_dir /data/180316_NB501073_0036_AH3VFKBGX5"
```

### Archer

To run the included ArcherDX analysis demultiplexing workflow, run:


```
make run-Archer
```

The same configuration details from the NGS580 workflow also apply

### HPC Cluster submission

The parent Nextflow process can be submitted to run as a `qsub` job with the `submit-phoenix-NGS580` Makefile recipe. Example: 

```
make submit-phoenix-NGS580
```

_NOTE:_ This only runs the parent Nextflow process as a cluster job; Nextflow already submits its processes as cluster jobs themselves, as per profile configurations in `nextflow.config`. 

# Configuration

Demultiplexing metadata for the workflow can be provided through several methods, evaluated in the following order:

- parameters can be supplied directly to Nextflow via CLI

```
nextflow run main.nf --runID 12345
```

- if the file `config.json` is present, non-`null` parameters will be retrieved

```
{
    "runDir": "/ifs/data/molecpathlab/quicksilver/170616_NB501073_0014_AH2VVMBGX3",
    "samplesheet": "SampleSheet.csv",
    "runID": "170616_NB501073_0014_AH2VVMBGX3"
}
```

  - this file is generated automatically during the `deploy` step, using the included `config.py` script

- the following items in the current directory will be used if present:

  - `SampleSheet.csv`: default samplesheet file

  - `runDir` : default sequencing run source directory (can be a symlink)
  
  - `runID.txt`: a text file, the first line of which will be used as the run ID

# Software Requirements

- Java 8 (Nextflow)

- `bcl2fastq` version 2.17.1

- FastQC version 0.11.7

- Python 2.7+

- R (3.3.0+ recommended, with `knitr` and `rmarkdown` installed)

- Pandoc 1.13.1+
