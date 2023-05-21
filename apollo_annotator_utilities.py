#!/usr/bin/env python3

name = 'apollo_annotator_utilities.py'
version = '0.1.1'
updated = '2023-05-20'

usage = f"""
NAME		{name}
VERSION		{version}
UPDATED		{updated}
SYNOPSIS	Interface between Apollo Arrow, Apollo, and the user that minimizes intermidiate steps.

REQUIRES	Apollo (https://github.com/GMOD/Apollo)
		python-apollo (https://github.com/galaxy-genome-annotation/python-apollo)
		$APOLLO enviromental variable (/path/to/Apollo_distribution)

------------------------------------------------------------------------------------------------------------------------
Add an Organism
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --add_organism \\
		 -f 50507.fasta \\
		 -g Encephalitozoon \\
		 -s intestinalis \\
		 -i E_intestinalis_50507 \\
		 -p /media/FatCat/apollo_data/E_intestinalis_50507

-f (--fasta)	Assembly fasta file
-g (--genus)	Genus
-s (--species)	Species
-i (--id)	Organism ID
-p (--path)	Path to store organism data

------------------------------------------------------------------------------------------------------------------------
Delete an Organism
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --delete_organism \\
		 -i E_intestinalis_50507

-i (--id)	Organism ID

------------------------------------------------------------------------------------------------------------------------
Load Annotations
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --load_annotations \\
		 -i E_intestinalis_50507 \\
		 -a proteins.long.gff

-i (--id)	Organism ID
-a (--annot)	Annotation gff file

------------------------------------------------------------------------------------------------------------------------
Remove Annotations
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --remove_annotations \\
		 -i E_intestinalis_50507

-i (--id)	Organism ID

------------------------------------------------------------------------------------------------------------------------
Add a Reference
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --add_reference \\
		 -a E_intestinalis_50506.blast.gff \\
		 -t match,match_part \\
		 -l E_intestinalis_50506 \\
		 -d -d /media/FatCat/apollo_data/E_intestinalis_50507

-r (--ref)	Reference gff file
-t (--type)	Reference type (CDS;match,match_part;tRNA)
-l (--label)	Reference label
-p (--path)	Path to store organism data
-c (--color)	Track color

------------------------------------------------------------------------------------------------------------------------
Remove a Reference
------------------------------------------------------------------------------------------------------------------------

COMMAND		{name} --remove_reference \\
		 -l E_intestinalis_50506 \\
		 -d /media/FatCat/apollo_data/E_intestinalis_50507

-l (--label)	Reference label
-p (--path)	Organism data location (apollo/data/organism)

------------------------------------------------------------------------------------------------------------------------
"""

from sys import argv

if len(argv) < 2:
	print(f"\n{usage}")
	exit()

from argparse import ArgumentParser
from subprocess import run
from os import environ

GetOptions = ArgumentParser()
group = GetOptions.add_mutually_exclusive_group(required=True)

group.add_argument("--add_organism")
group.add_argument("--delete_organism")

group.add_argument("--load_annotations")
group.add_argument("--remove_annotations")

group.add_argument("--add_reference")
group.add_argument("--remove_reference")

args = GetOptions.parse_args()

add_org = args.add_organism
del_org = args.delete_organism
load_annot = args.load_annotations
rem_annot = args.remove_annotations
add_ref = args.add_reference
rem_ref = args.remove_reference

APOLLO = environ['APOLLO']

if add_org:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-f","--fasta",required=True)
	GetOptions.add_argument("-g","--genus",required=True)
	GetOptions.add_argument("-s","--species",required=True)
	GetOptions.add_argument("-i","--id",required=True)
	GetOptions.add_argument("-p","--data_path",required=True)

	args = GetOptions.parse_args()

	fasta = args.fasta
	genus = args.genus
	species = args.species
	org_id = args.id
	path = args.data_path

	run([f"{APOLLO}/web-apps/jbrowse/bin/prepare-refseqs.pl","--fasta",fasta,"--out",path])

	run(["arrow","organisms","add_organisms","--genus",genus,"--species",species,org_id,path])

if del_org:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-i","--id",required=True)

	args = GetOptions.parse_args()

	org_id = args.id

	run(["arrow","organsisms","delete_features",org_id])
	run(["arrow","organsisms","delete_organism",org_id])

if load_annot:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-i","--id",required=True)
	GetOptions.add_argument("-a","--annot",required=True)

	args = GetOptions.parse_args()

	org_id = args.id
	annot = args.annot

	run(['arrow','annotations','load_gff3',org_id,annot])

if rem_annot:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-i","--id",required=True)

	args = GetOptions.parse_args()

	org_id = args.id

	run(['arrow','annotations','delete_features',org_id])

if add_ref:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-r","--ref",required=True)
	GetOptions.add_argument("-t","--type",required=True)
	GetOptions.add_argument("-l","--label",required=True)
	GetOptions.add_argument("-p","--data_path",required=True)
	GetOptions.add_argument("-c","--color",default='blue')

	args = GetOptions.parse_args()

	ref = args.ref
	type = args.type
	label = args.label
	path = args.data_path
	color = args.color

	run([f'{APOLLO}/web-app/jbrowse/bin/flatfile-to-json.pl','--gff',ref,'--type',type,'--trackLabel',label,'--out',path,'subfeatureClasses',f"'{{\"match_part\":\"{color}\"}}'"])

if rem_ref:

	GetOptions = ArgumentParser()

	GetOptions.add_argument("-l","--label",required=True)
	GetOptions.add_argument("-p","--data_path",required=True)

	args = GetOptions.parse_args()

	label = args.label
	path = args.data_path

	run([f"{APOLLO}/bin/remove-track.pl",'--trackLabel',label,'--delete','--dir',path])