#!/usr/bin/env python3

name = 'tRNAscan_to_apollo_gff.py'
version = '0.1.0'
updated = '2023-05-20'

usage = f"""
NAME		{name}
VERSION		{version}
UPDATED		{updated}
SYNOPSIS	Converts tRNAscan-SE output files to Apollo compatible GFF format.

USAGE	{name} -t 50507.tRNA

OPTIONS
-t (--tRNA)	tRNAscan output file
"""

from sys import argv

if len(argv) < 2:
	print(f"{usage}")
	exit()

from argparse import ArgumentParser
from os.path import basename

GetOptions = ArgumentParser()

GetOptions.add_argument("-t","--tRNA",required=True)

args = GetOptions.parse_args()

tRNA_file = args.tRNA
filename = basename(tRNA_file).split(".")[0]

TRNA = open(tRNA_file,'r')
GFF = open(f"{filename}.tRNA.gff",'w')
INTRON = open(f"{filename}.tRNA.introns",'w')

nucleotide = {'A':'U','C':'G','G':'C','T':'A'}

line_num = 1
tRNA = 1
for line in TRNA:
	
	if line_num > 3:

		data = line.strip().split("\t")

		chromosome = data[0].strip()
		start = int(data[2].strip())
		end = int(data[3].strip())
		amino = data[4].strip()
		codon = "".join([nucleotide[x] for x in data[5].strip()[::-1]])
		istart = int(data[6].strip())
		iend = int(data[7].strip())
		score = data[8].strip()

		strand = '+'
		if start > end:
			strand = '-'
			start,end = end,start
			istart,iend = iend,istart

		GFF.write(f"{chromosome}\ttRNAscan-SE\ttRNA\t{start}\t{end}\t{score}\t{strand}\t.\t")
		GFF.write(f"ID=tRNA_{tRNA};Name=tRNA_{tRNA};Note=tRNA:{amino}({codon})\n")

		if istart != 0 and iend != 0:
			INTRON.write(f"{chromosome}\t{amino}\tjoin({start}..{istart},{iend}..{end})\n")

		tRNA += 1

	else:

		line_num += 1

	line_num

TRNA.close()
GFF.close()
INTRON.close()