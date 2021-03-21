#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'Blast2GFF3.pl';
my $version = '0.3a';
my $update = '3/21/2021';

my $usage = <<"EXIT";

NAME		${name}
VERSION		${version}
SYNOPSIS	This script converts the output of a (t)blastn.6 file to GFF3 format for loading into Apollo (https://github.com/GMOD/Apollo) 

COMMAND		blast2gff3.pl \\
			-i *.(t)blast(n).6 \\
			-f *.fna

OPTIONS

-i | --in		(t)blastn.6 file to be converted
-f | --fa		faa/fna file that is connected to (t)blastn.6 file
-p | --prod		File containing locus => product information
-o | --orgn		Organism title in .fna file (i.e. 'Encephalitozoon hellem ATCC 50504')

EXIT

die($usage) unless(@ARGV);

my $in;
my $fa;
my $prod;
my $orgn="";
GetOptions(
	"i|in=s" => \$in,
	"f|fa=s" => \$fa,
	"p|prod=s" => \$prod,
	"o|orgn=s" => \$orgn
);

## Set up file handles for data acquisition and storing
my $ext;
if ($in =~ /\.tblastn\.6$/) { $ext = '.tblastn.6'; }
else { $ext = '.blastn.6'; }
$ext = uc($ext);
my ($filename,$dir) = fileparse($in);
my $basename = basename($filename,$ext);

if($ext eq "TBLASTN") { $orgn = ""; }

## Check to see what file is being fed as an input for locus => product relation
## and open that file. If both .fna and *_product.txt is feed, *_product.txt is defaulted.

## Populate a database containing the protein match and tieing it to the locus tag
my %products;
if($prod){ 
	open PROD,"<","$prod"; 
	while (my $line = <PROD>){
		chomp $line;
		if ($line =~ /^(\S+)\t(.*)/){
			my $locus = $1;
			my $product = $2;
			$products{$locus} = $product;
		}
	}	
}
elsif($fa) { 
	open PROD,"<","$fa"; 
	while (my $line = <PROD>){
		chomp $line;
		if($line =~ /^>(\S+)\s+$orgn(.*)\s+\[/){
			my $locus = $1;
			my $product = $2;
			$products{$locus} = $product;
			next;
		}
		if($line =~ /^>(\S+)\s+$orgn(.*)\s+\(/){
			my $locus = $1;
			my $product = $2;
			$products{$locus} = $product;
			next;
		}
		if($line =~ /^>(\S+)\s+$orgn(.*)/){
			my $locus = $1;
			my $product = $2;
			$products{$locus} = $product;
			next;
		}
	}
}


open BLAST,"<","${in}";
open OUT,">","${basename}.gff";

## Convert blast information to gff3 format
my $hit;
while (my $line = <BLAST>){
	chomp $line;
	if ($line =~ /^\#/) { next; }
	else{
		my @info = split("\t",$line);
		my $query = $info[0]; 		## protein accession number
		my $target = $info[1];		## location of the hit (contig or chromosome)
		my $identity = $info[2];  	## identity %
		my $len = $info[3];			## alignment length
		my $mis = $info[4];			## mismatches
		my $gap = $info[5];			## gaps
		my $qstart = $info[6];		## query start
		my $qend = $info[7];		## query end
		my $tstart = $info[8];		## target start
		my $tend = $info[9];		## target end
		my $evalue = $info[10];		## evalue
		my $bit = $info[11];		## bitscore
		my $product = $products{$query};
		$hit++;
		if ($tstart < $tend){
			print OUT "$target"."\t".$ext."\t"."match"."\t"."$tstart"."\t"."$tend"."\t";
			print OUT "$evalue"."\t".'+'."\t".'.'."\t"."ID=hit$hit".';'."Name=hit$hit".';';
			print OUT "Note=$query".':'."$product"."\n";

			print OUT "$target"."\t".$ext."\t"."match_part"."\t"."$tstart"."\t"."$tend";
			print OUT "\t"."$evalue"."\t".'+'."\t"."0"."\t"."gene_id=hit$hit".';'."Parent=hit$hit";
			print OUT ';'."transcript_id=hit$hit.t1".';'."Note=$query".':'."$product"."\n";
		}
		elsif ($tstart > $tend){
			print OUT "$target"."\t".$ext."\t"."match"."\t"."$tend"."\t"."$tstart"."\t";
			print OUT "$evalue"."\t".'-'."\t".'.'."\t"."ID=hit$hit".';'."Name=hit$hit".';';
			print OUT "Note=$query".':'."$product"."\n";

			print OUT "$target"."\t".$ext."\t"."match_part"."\t"."$tend"."\t"."$tstart";
			print OUT "\t"."$evalue"."\t".'-'."\t"."0"."\t"."gene_id=hit$hit".';'."Parent=hit$hit";
			print OUT ';'."transcript_id=hit$hit.t1".';'."Note=$query".':'."$product"."\n";
		}
	}
}
