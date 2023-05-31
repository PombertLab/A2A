#!/usr/bin/env python3

name = 'blast_to_apollo_gff.py'
version = '0.2.0'
updated = '2023-05-31'

usage = f"""
NAME		{name}
VERSION		{version}
UPDATED		{updated}
SYNOPSIS	Converts tabular BLAST output files to Apollo compatible GFF3 format.

USAGE		{name} \\
		 -b E_hellem_50604.tblastn.6 \\
		 -a E_hellem_50604.products

OPTIONS
-b (--blast)	Tabular BLAST file
-a (--annots)	Tab-separated file locus-annotation file for the query used
-o (--output)	Output file [Default: blast.gff3]
"""

from sys import argv

if len(argv) < 2:
	print(f"\n{usage}")
	exit()

from argparse import ArgumentParser
from os.path import basename

GetOptions = ArgumentParser()

GetOptions.add_argument("-b","--blast",required=True)
GetOptions.add_argument("-a","--annots",required=True)
GetOptions.add_argument("-o","--output",default="blast.gff3")

args = GetOptions.parse_args()

blast_file = args.blast
annots_file = args.annots
output = args.output

basename = basename(blast_file).split(".")
filename = basename[0]
ext = basename[-2]

PRODUCTS = open(annots_file,'r')
products = {}
for line in PRODUCTS:
	line.strip()
	locus,annot = line.split("\t")[0:2]
	products[locus] = annot.strip()
PRODUCTS.close()

BLAST = open(blast_file,'r')
GFF3 = open(output,'w')
match_num = 1
for line in BLAST:
	
	line = line.strip()
	
	data = line.split("\t")
	
	query = data[0]
	target = data[1]
	tstart,tend = int(data[8]),int(data[9])
	evalue = data[10]

	strand = '+'
	if tstart > tend:
		strand = '-'
		tstart,tend = tend,tstart

	product = "Unavailable"
	if query in products.keys():
		product = products[query]

	GFF3.write(f"{target}\t{ext}\tmatch\t{tstart}\t{tend}\t{evalue}\t{strand}\t.\t")
	GFF3.write(f"ID=hit_{match_num};Name=hit_{match_num};Note={query}:{product}\n")
	
	GFF3.write(f"{target}\t{ext}\tmatch_part\t{tstart}\t{tend}\t{evalue}\t{strand}\t.\t")
	GFF3.write(f"gene_id=hit_{match_num};Parent=hit_{match_num};transcript_id=hit_{match_num}.t1;Note={query}:{product}\n")

	match_num += 1

BLAST.close()
GFF3.close()