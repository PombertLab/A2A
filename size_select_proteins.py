#!/usr/bin/env	python3

name = "size_select_proteins.py"
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
	print(f"\nusage")
	exit()


from argparse import ArgumentParser
from os import makedirs
from os.path import isdir,basename

GetOptions = ArgumentParser()

GetOptions.add_argument("-g","--gff",required=True)
GetOptions.add_argument("-a","--aa_len",default=60,type=int)
GetOptions.add_argument("-o","--outdir",default="SIZE_SORTED_PROTEINS")

args = GetOptions.parse_args()

gff_file = args.gff
aa_len = args.aa_len
outdir = args.outdir

if not isdir(outdir):
	makedirs(outdir,mode=0o755)

filename = basename(gff_file).split(".")[0]

GFF = open(gff_file,'r')
LONG = open(f"{outdir}/{filename}.long.gff",'w')
SHORT = open(f"{outdir}/{filename}.short.gff",'w')

for line in GFF:
	line = line.strip()
	if line[0] == "#":
		LONG.write(f"{line}\n")
		SHORT.write(f"{line}\n")
	else:
		start,end = line.split("\t")[3:5]
		if int(abs(int(end)-int(start))/3) >= aa_len:
			LONG.write(f"{line}\n")
		else:
			SHORT.write(f"{line}\n")

GFF.close()
LONG.close()
SHORT.close()