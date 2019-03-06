#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Mark a run's output as 'passed' by placing a symlink in the output directory
"""
import sys
import os
from util import samplesheet
samplesheet_file = sys.argv[1]
outputDir = os.path.join("output", "reads")

sheet_obj = samplesheet.IEMFile(path = samplesheet_file)

sample_projects = list(set([sample['Sample_Project'] for sample in sheet_obj.data['Data']['Samples']]))

for i, sample_project in enumerate(sample_projects):
    src = os.path.join(outputDir, sample_project)
    dest = os.path.join(outputDir, "passed{0}".format(i))
    print(">>> Linking {0} to {1}".format(src, dest))
    if os.path.exists(dest):
        os.unlink(dest)
    os.symlink(sample_project, dest)
