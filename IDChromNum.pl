#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'IDChromNum.pl';
my $version = '0.4b';
my $updated = '3/21/21';
my $usage = <<"EXIT";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	The purpose of this script is to read through a taxonomized blast file and determine
			the chromosome number of each contig in an assembly.

COMMAND		${name} \\
			-f E_cuni.assembly.fasta \\
			-p E_cuni.proteins.fasta \\
			-d /media/FatCat/Databases/Ecun

OPTIONS

-f | --fast			Final assembly file
-p | --proteins		Protein prediction file
-d | --db			"/path/to/organism/database"
-r | --replace		Replace contig # with chromosome # in fasta file [default = off]
-v | --verb			Output information about chromosome search and labeling [default = off]
EXIT
die("\n$usage\n") unless(@ARGV);

my $fa;
my $prot;
my $db;
my $replace;
my $v;
GetOptions(
	"f|fast=s" => \$fa,
	"p|proteins=s" => \$prot,
	"d|db=s" => \$db,
	"r|replace" => \$replace,
	"v|verb" => \$v
);

## Get database name from database directory
my $db_name;
if($db =~ /.+?\/(.+)/){
	$db_name = $1;
}

## Complete tblastn on assembly
system("tblastn \\
		-query $prot \\
		-db $db_name\\
		-culling_limit 1 \\
		-outfmt 6 \\
		-out proteins.tblastn.6
");

## Acquire file information
my($bout,$bpath) = fileparse("proteins.tblastn.6");
my $bbasename = basename($bout,".tblastn.6");

## Search for feature table in database directory
opendir(DIR,$db);
my $ft;
foreach (my $file = <DIR>){
	if($file =~ /feature_table/){
		$ft = $db."/".$file;
	}
}
closedir(DIR);
die("[E] Feature table not found in database.\n") unless($ft);

open BLAST,"<","proteins.tblastn.6";
open FEAT,"<","${ft}";
open BOUT,">","$bbasename.chromo.tblastn.6";
open FOUT,">","chromo.fasta";
open LOG,">","chromosome.log";
open LOG2,">","consensus.log";
open FAST,"<","${fa}";

## Getting the chromosome => accession number correspondance
## from the NCBI feature table file 
my %chromosome;
while (my $line = <FEAT>){
	chomp($line);
	if ($line =~ /^#/){ next;} ## Skip the table headers
	## Looking for Chromosome# ($columns[5]) and Accession# ($columns[6])
	my @columns = split("\t", $line);
$chromosome{$columns[6]} = $columns[5]; 
}
## Parsing BLAST file to link accession numbers => contig number
my %consensus;
while (my $line = <BLAST>){
	if ($line =~ /^\S+?_(\d*)\S*\t(\S*)/){
		my $contig = $1; my $accession_number = $2;
		KEY: foreach my $accession_key (keys %chromosome){
			if($line =~ /$accession_key/){
				$accession_number = $accession_key;
				last KEY;
			}
		}
		if($consensus{$contig}{$accession_number}){
			$consensus{$contig}{$accession_number}++;
		}
		else{
			$consensus{$contig}{$accession_number} = 1;
		}
	}
}

## Linking contig number => chromosome number. The most present accession number on a contig
## is assumed to be the accession number for the entire contig.
my %contig_chrom_link;
foreach my $contig_key (sort keys %consensus){
	my $max_accession_num = 0;
	my $max_accession_key;
	my $total_proteins = 0;
	my %contig_hash =  %{$consensus{$contig_key}};
	print LOG2 ">contig_$contig_key\n";
	if($v){ print "\nContig $contig_key Chromosome Consensus\n"; }
	foreach my $accession_key (keys %contig_hash){
		my $accession_num = $consensus{$contig_key}{$accession_key};
		$total_proteins += $accession_num;
		if ( $accession_num > $max_accession_num){
			$max_accession_num = $consensus{$contig_key}{$accession_key};
			$max_accession_key = $accession_key;
		}
		# print("Chromosome $chromosome{$accession_key}\n");
		# print("Accession Key $accession_key\n");
		if($v) { print "Chromosome $chromosome{$accession_key}\t$accession_num\n"; }
		print LOG2 "Chromosome_$chromosome{$accession_key}\t$accession_num\n";
	}
	my $match_percent = sprintf("%.2f",$max_accession_num/$total_proteins*100);
	if($v){ 
		print "Contig $contig_key is a $match_percent% match for Chromosome $chromosome{$max_accession_key}\n";
		unless ($match_percent > 50) { print "Data is not sufficient enough to make a sound prediction\n" } 
	}
	$contig_chrom_link{$contig_key} = $chromosome{$max_accession_key};
	print LOG "contig_$contig_key\t$chromosome{$max_accession_key}\t$match_percent\n";
}
close(BLAST);

open BLAST,"<","proteins.tblastn.6";
## Replacing Accession # in the blast.6 file with the assumed Chromosome #
while (my $line = <BLAST>){
		chomp($line);
		if($line =~ /^\S+?_(\d*)\S+\t(\S+)/){
				my $org = $2;
				my $rep = $contig_chrom_link{$1};
				$line =~ s/$org/Chromosome_$rep/;
				$line =~ s/_pilon//;
				print BOUT ("$line\n");
		}
}

## Replacing Accession # in the fasta file with the assumed Chromosome #
my $exists = 1;
if($replace){
	open NM,">","no_match.log";
	while (my $line = <FAST>){
		chomp($line);
		if ($line =~ /^\S+?_(\d+)/){
			unless (exists $contig_chrom_link{$1}){
				$exists = 0;
				print NM "$line\n";
				next;
			}
			$exists = 1;
			my $some = $contig_chrom_link{$1};
			print FOUT "$line\n";
			next;
		}
		if ($exists == 0){ print NM "$line\n"; }
		else { print FOUT "$line\n"; }
	}
}
else{
	while (my $line = <FAST>){
		chomp($line);
		print FOUT "$line\n";
	}
}