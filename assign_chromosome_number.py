#!/usr/bin/env python3

name = "assign_chromosome_number.py"
version = "0.1.0"
updated = "2023-05-17"

usage = f"""
NAME
VERSION
UPDATED
SYNOPSIS

USAGE

OPTIONS


"""

from sys import argv

if len(argv) < 2:
	print(f"\n{usage}")
	exit()

from argparse import ArgumentParser
from os import makedirs
from os.path import isdir,basename
from textwrap import wrap

GetOptions = ArgumentParser()

GetOptions.add_argument("-m","--map",required=True)
GetOptions.add_argument("-f","--fasta",required=True)
# GetOptions.add_argument("-t","--type",choices=['a','n'],default='n')
GetOptions.add_argument("-o","--outdir",default="CHROMOSOME_ASSIGNMENT")

args = GetOptions.parse_args()

map_file = args.map
fasta_file = args.fasta
# subset_type = args.type
outdir = args.outdir

if not isdir(outdir):
	makedirs(outdir,mode=0o755)

filename = basename(fasta_file).split(".")[0]

FASTA = open(fasta_file,'r')
locus = ""
contigs = {}
for line in FASTA:
	line = line.strip()
	if line[0] == ">":
		locus = line[1:]
		contigs[locus] = ""
	else:
		contigs[locus] += line
FASTA.close()

MAP = open(map_file,'r')
mappings = {}
mapped_to = ""
for line in MAP:
	line = line.strip()
	if line != "":
		if line[0:2] == ">>":
			mapped_to = line[2:].split("\t")[0]
			mappings[mapped_to] = []
		elif line[0] == ">":
			mapped,type = line[1:].split("\t")[0:2]
			if type == "Primary":
				mappings[mapped_to].append(mapped)
MAP.close()


ASSIGNED_FASTA = open(f"{outdir}/{filename}.assigned.fasta",'w')
ASSIGNMENTS = open(f"{outdir}/{filename}.chromosome_assignments",'w')

for chromosome in sorted(mappings.keys()):
	for index,contig in enumerate(mappings[chromosome]):
		ASSIGNED_FASTA.write(f">{chromosome}s{index+1}\n")
		sequence = "\n".join(wrap(contigs[contig],60))
		ASSIGNED_FASTA.write(f"{sequence}\n")
		ASSIGNMENTS.write(f"{contig} => {chromosome}s{index+1}\n")
ASSIGNED_FASTA.close()
ASSIGNMENTS.close()