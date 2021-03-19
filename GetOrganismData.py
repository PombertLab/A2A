#!/usr/bin/python

from sys import exit,argv
import re

name = "GetOrganismData.py"
version = "0.2b"
updated = "3/14/21	Changed output directory name to match DB name"

usage = f"""\n
NAME        {name}
VERSION     {version}
UPDATED     {updated}
SYNOPSIS    The purpose of this script is to navigate the NCBI genome database, download the required files to 
            create a protein and genomic database, as well as download files required for the A2A pipeline.

COMMAND     {name} -k fungi -g Encephalitozoon -s hellem

OPTIONS

-p | --path         Location for data download [default = ./]
-k | --kingdom      Kingdom of the desired organism
-g | --genus        Genus of the desired organism
-s | --species      Species of the desired organism
\n"""

if (len(argv) == 1):
    print(f"{usage}")
    exit()

from os import system
import argparse
import pathlib

## loading all the necessary packages for web scraping
from selenium import webdriver 
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.firefox.options import Options

path = pathlib.Path.cwd()

## Setup GetOptions
parser = argparse.ArgumentParser(usage=usage)
parser.add_argument("-p","--path")
parser.add_argument("-k","--kingdom",required=True)
parser.add_argument("-g","--genus",required=True)
parser.add_argument("-s","--species",required=True)

args = parser.parse_args()

kingdom = args.kingdom
kingdom = kingdom.lower()
genus = args.genus
genus = (genus.lower()).capitalize()
species = args.species
species = species.lower()
path = args.path

db_dir = genus[0]+species[0:3]
db = genus[0]+species[0:3]
odir = pathlib.Path(f"{path}/{db_dir}")
if not odir.exists():
    system(f"mkdir {odir}")

system(f"echo 'Searching for {genus} {species} in the {kingdom} folder in the NCBI database'")

## Creating web scraper
options = Options()
options.headless = True
driver = webdriver.Firefox(options=options)

## Open the NCBI genome database
driver.get("https://ftp.ncbi.nlm.nih.gov/genomes/refseq/")

data = ["_genomic.fna.gz","_protein.faa.gz","_rna.fna.gz","_feature_table.txt.gz","_assembly_report.txt"]

## Search for the kingdom specified
try:
	WebDriverWait(driver,60).until(EC.presence_of_element_located((By.LINK_TEXT,kingdom+"/"))).click()
except:
	print("[E] The kingdom you are searching for does not exist in the NCBI database.\n")
	driver.quit()

## Search for the organism specifed
try:
	WebDriverWait(driver,60).until(EC.presence_of_element_located((By.LINK_TEXT,genus+"_"+species+"/"))).click()
except:
	print("[E] Either the organism you are searching for does not exist in the NCBI database or connection to the NCBI database failed.\n")
	driver.quit()

## Navigate to the most recent version
try:
	WebDriverWait(driver,60).until(EC.presence_of_element_located((By.LINK_TEXT,"latest_assembly_versions/"))).click()
except:
	driver.quit()

## Enter the database for the organism
try:
	WebDriverWait(driver,60).until(EC.presence_of_element_located((By.PARTIAL_LINK_TEXT,"GCF"))).click()
except:
	driver.quit()

assembly_version = (driver.title).split("/")[-1]

for key in data:
	key = assembly_version + key
	download = WebDriverWait(driver,60).until(EC.presence_of_element_located((By.PARTIAL_LINK_TEXT,key))).get_attribute('href')
	info = str(download).split("/")
	system(f"wget {download} -O {odir}/{info[-1]}")
	regex = re.compile(".gz")
	if regex.search(info[-1]):
		system(f"gzip -df {odir}/{info[-1]}")
	info[-1] = info[-1].replace(".gz","")
	if(key == assembly_version + "_genomic.fna.gz"):
		system(f"makeblastdb -in {odir}/{info[-1]} -dbtype nucl -out {odir}/{db}")
	elif(key == assembly_version + "_protein.faa.gz"):
		system(f"makeblastdb -in {odir}/{info[-1]} -dbtype prot -out {odir}/{db}")