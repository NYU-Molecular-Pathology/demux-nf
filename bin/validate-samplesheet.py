#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Runs validation checking on the provided Illumina samplesheet file for bcl2fastq
"""
import sys
from util import samplesheet
samplesheet_file = sys.argv[1]
sheet_obj = samplesheet.IEMFile(path = samplesheet_file)
sheet_obj.isValid(_raise = True)
