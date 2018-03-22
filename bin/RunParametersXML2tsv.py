#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Convert a `RunParameters.xml` file to .tsv format
"""
import csv
from util import samplesheet
run_params_file = "RunParameters.xml"
run_tsv_output_file = "RunParameters.tsv"
run_params = samplesheet.RunParametersXML(path = run_params_file)

with open(run_tsv_output_file, "w") as f:
    writer = csv.DictWriter(f, delimiter = "\t", fieldnames = run_params.data.keys())
    writer.writeheader()
    writer.writerow(run_params.data)
