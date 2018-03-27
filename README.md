# demux-nf
Nextflow pipeline for demultiplexing

# Installation

Clone this repository

```
git clone https://github.com/NYU-Molecular-Pathology/demux-nf.git
cd demux-nf
```
# Usage

The easiest way to run the pipeline is by using the included `Makefile`, which has shortcuts to preset execution configurations, with the sequencer output directory name provided as an argument to `PROJECT`. Extra parameters for Nextflow can be provided with `EP`.

_NOTE:_ By default, the pipeline will run in the _current session_ in your terminal. To run the pipeline in the background, it is recommended to either run it in `screen` or use the included cluster submission script (`submit.sh`).

## NGS580 Demultiplexing on NYU phoenix

```
make run-NGS580 PROJECT=<project ID>
```

- Example:

```
make run-NGS580 PROJECT=180213_NB501073_0034_AHWJLLAFXX
```

with extra parameters:

```
make run-NGS580 PROJECT=180213_NB501073_0034_AHWJLLAFXX EP="--samplesheet /ifs/data/molecpathlab/quicksilver/180213_NB501073_0034_AHWJLLAFXX/Data/Intensities/BaseCalls/og.SampleSheet.csv -resume"
```

### Cluster submission script

The included `submit.sh` script can be used to run Nextflow as a cluster job. Just pass it all the args that be passed to the `Makefile`. Example usage:

```
./submit.sh 'run-NGS580 PROJECT=180213_NB501073_0034_AHWJLLAFXX EP="--samplesheet /ifs/data/molecpathlab/quicksilver/180213_NB501073_0034_AHWJLLAFXX/Data/Intensities/BaseCalls/og.SampleSheet.csv -resume"'
```

_NOTE:_ This only runs the parent Nextflow process as a cluster job; Nextflow already submits its processes as cluster jobs themselves as per configurations. 

# Software Requirements

- Java 8 (Nextflow)

- `bcl2fastq` version 2.17.1

- FastQC version 0.11.7

- R (3.3.0+ recommended, with `knitr`)

- Pandoc 1.13.1+

- GraphViz Dot (to compile flowchart)

