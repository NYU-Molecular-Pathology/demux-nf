#!/usr/bin/env python
# -*- coding: utf-8 -*-
#### ~~~~~~~~~~~ Sophia Genetics specific ~~~~~~~~~~~ ####
"""
Move FASTQ files into a project directory and mark the run as 'passed'
by placing a symlink (passed0 -> <Project Name>) in the output directory.
"""
import sys
import os
import shutil
from util import samplesheet

samplesheet_file = sys.argv[1]
outputDir = os.path.join("output", "reads")

sheet_obj = samplesheet.IEMFile(path=samplesheet_file)

# Get Project Name from [Header] section
project_name = sheet_obj.data.get('Header', {}).get('Project Name')
if not project_name:
    raise ValueError("ERROR: 'Project Name' not found in samplesheet [Header] section")

# Get all Sample_IDs from [Data] section
sample_ids = [sample['Sample_ID'] for sample in sheet_obj.data['Data']['Samples']]

# Create the project output directory
project_dir = os.path.join(outputDir, project_name)
os.makedirs(project_dir, exist_ok=True)
print(">>> Created project directory: {0}".format(project_dir))

# Copy FASTQ files for each sample into the project directory
# FASTQs are expected to match: output/reads/<Sample_ID>*.fastq.gz
for sample_id in sample_ids:
    found = False
    for fname in os.listdir(outputDir):
        if fname.startswith(sample_id) and (fname.endswith('.fastq.gz') or fname.endswith('.fastq.gz.md5.txt')):
            src = os.path.join(outputDir, fname)
            dest = os.path.join(project_dir, fname)
            print(">>> Moving {0} -> {1}".format(src, dest))
            shutil.move(src, dest)
            found = True
    if not found:
        print("WARNING: No FASTQ files found for sample '{0}' in {1}".format(sample_id, outputDir))

# Create symlink: passed0 -> PACTID
symlink_dest = os.path.join(outputDir, "passed0")
if os.path.exists(symlink_dest) or os.path.islink(symlink_dest):
    os.unlink(symlink_dest)
print(">>> Linking {0} -> {1}".format(symlink_dest, project_name))
os.symlink(project_name, symlink_dest)