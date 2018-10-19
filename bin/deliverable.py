#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Set up a directory to separate out deliverable sample .fastq files
"""
import sys
import os
import json
import datetime
from util import find

configJSON = "config.json"
outputDir = 'output/Unaligned'
deliverableDir = 'deliverable'
deliverableID = sys.argv[1]
deliverables_sheet = sys.argv[2]

# load JSON config
with open(configJSON) as f:
    config = json.load(f)

# get the date for the run from the first 6 digits of the runID
runDate = datetime.datetime.strptime(config['runID'][:6], '%y%m%d').strftime('%Y-%m-%d')

# read list of sampleIDs from the deliverables sheet
sampleIDs = []
with open(deliverables_sheet) as f:
    for line in f:
        sampleIDs.append(line.strip())

# find all matching .fastq.gz files in the output locations
deliverableFiles = []
for sampleID in sampleIDs:
    for item in find.find(search_dir = outputDir, inclusion_patterns = ['{0}*.fastq.gz'.format(sampleID)]):
        deliverableFiles.append(item)
deliverableFiles = list(set(deliverableFiles))

# set up deliverables directories
deliverableSubdir = os.path.join(deliverableDir, deliverableID, runDate, 'fastq')
try:
    os.makedirs(deliverableSubdir)
except OSError:
    if not os.path.isdir(deliverableSubdir):
        raise

# symlink the files to the deliverables dir
for item in deliverableFiles:
    dest = os.path.join(deliverableSubdir, os.path.basename(item))
    rel_path = os.path.relpath(item, deliverableSubdir)
    # print((item, dest, rel_path))
    if not os.path.exists(dest):
        print(">>> Symlinking {0} to {1}".format(item, dest))
        os.symlink(rel_path, dest)
    else:
        print(">>> Skipping pre-exisiting item: {0}".format(dest))
