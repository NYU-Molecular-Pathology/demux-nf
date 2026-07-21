#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Runs validation checking on the provided Illumina samplesheet file for bcl2fastq
"""
import sys
from util import samplesheet_bclconvert
samplesheet_file = sys.argv[1]
sheet_obj = samplesheet_bclconvert.BCLConvertFile(path = samplesheet_file)
sheet_obj.isValid(_raise = True)
