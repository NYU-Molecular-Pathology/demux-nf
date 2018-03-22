# demux-nf
Nextflow pipeline for demultiplexing

# Installation

Clone this repository

```
git clone https://github.com/NYU-Molecular-Pathology/demux-nf.git
cd demux-nf
```

Install Nextflow in the local directory

```
make install
```

(Optional) Test that it worked

```
make test
```

# Contents

- `main.nf`: main Nextflow pipeline file

- `nextflow.config`: Nextflow configuration file

- `bin`: directory for scripts to use inside the Nextflow pipeline; its contents will be prepended to your `PATH` when pipeline tasks are executed

- `Makefile`: shortcuts to common pipeline actions

# Software Requirements

- Java 8 (Nextflow)

- GraphViz Dot (to compile flowchart)

- any other requirements needed by your pipeline tasks
