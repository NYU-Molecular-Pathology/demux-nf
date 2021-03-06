#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Creates an updated config file for the pipeline
"""
import json
import argparse

def make_config(data):
    """
    Prints JSON config to stdout
    """
    print(json.dumps(data, indent=4))

def update_config(updateFile, data, add = False):
    """
    Update the values of a JSON config file for non-null values in the provided data
    """
    f = open(updateFile)
    old_data = json.load(f)
    f.close()

    for key, value in data.items():
        if not add:
            if key in old_data:
                if value is not None:
                    old_data[key] = value
        else:
            if value is not None:
                old_data[key] = value

    f = open(updateFile, "w")
    json.dump(old_data, f, indent = 4)
    f.close()

def main(**kwargs):
    """
    Main control function for the script
    """
    runID = kwargs.pop('runID', None)
    runDir = kwargs.pop('runDir', None)
    demuxDir = kwargs.pop('demuxDir', None)
    samplesheet = kwargs.pop('samplesheet', None)
    system = kwargs.pop('system', None)
    seqType = kwargs.pop('seqType', None)
    updateFile = kwargs.pop('updateFile', False)
    add = kwargs.pop('add', False)

    data = {
    'runID': runID,
    'runDir': runDir,
    'demuxDir': demuxDir,
    'samplesheet': samplesheet,
    'system': system,
    'seqType': seqType
    }

    if updateFile is False:
        make_config(data)
    else:
        update_config(updateFile, data, add = add)

def parse():
    """
    Parses script args
    """
    parser = argparse.ArgumentParser(description='Creates an updated config file for the pipeline')
    parser.add_argument("--runID", default = None, dest = 'runID', help="Run ID")
    parser.add_argument("--runDir", default = None, dest = 'runDir', help="Run directory")
    parser.add_argument("--demuxDir", default = None, dest = 'demuxDir', help="Run directory")
    parser.add_argument("--samplesheet", default = None, dest = 'samplesheet', help="Samplesheet file")
    parser.add_argument("--system", default = None, dest = 'system', help="Hostname of the server being used")
    parser.add_argument("--seqType", default = None, dest = 'seqType', help="Identifier for the type of sequencing, e.g. Archer, NGS580, etc.")
    parser.add_argument("-u", "--update", default = False, dest = 'updateFile', help="JSON file to update")
    parser.add_argument('--add', action='store_true', dest = "add", help="forces the addition of missing keys to JSON config output")

    args = parser.parse_args()

    main(**vars(args))

if __name__ == '__main__':
    parse()
