#!/usr/bin/env python3

name = "prodigal_to_apollo_gff.py"
version = "0.1.1"
updated = "2023-05-20"

usage = f"""
NAME		{name}
VERSION		{version}
UPDATED		{updated}
SYNOPSIS	Adds the mRNA/exon feature to the Prodigal gff file to make it Apollo compatible.

USAGE		{name} \\
		 -g 50507.prodigal.gff

OPTIONS

"""

from sys import argv

if len(argv) < 2:
	print(f"\n{usage}")
	exit()

from argparse import ArgumentParser
from os.path import basename

GetOptions = ArgumentParser()

GetOptions.add_argument("-g","--gff",required=True)

args = GetOptions.parse_args()

gff_file = args.gff

filename = ".".join(basename(gff_file).split(".")[0:-1])

GFF = open(gff_file,'r')
AGFF = open(f"{filename}.apollo.gff3",'w')
for line in GFF:
	line = line.strip()
	if line[0] == "#":
		AGFF.write(f"{line}\n")
	else:
		data = line.split("\t")[0:-2]
		id_num = line.split("\t")[-1].split(";")[0][3:]
		data[2] = "mRNA"
		mRNA = "\t".join(data)
		AGFF.write(f"{mRNA}\t.\tID={id_num}_mRNA;\n")
		data[2] = "exon"
		exon = "\t".join(data)
		AGFF.write(f"{exon}\t0\tID={id_num}_exon;Parent={id_num}_mRNA;\n")
GFF.close()
AGFF.close()