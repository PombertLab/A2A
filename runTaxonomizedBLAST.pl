#!/usr/bin/perl
## Pombert Lab, IIT 2019
my $name = 'runTaxonomizedBLAST.pl';
my $version = '0.4.1';
my $updated = '2023-04-25';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use File::Path qw(make_path);

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs taxonomized BLAST searches, and returns the outfmt 6 format with columns staxids, sscinames, sskingdoms, and sblastnames
REQUIREMENTS	- BLAST 2.2.28+ or later
		- NCBI taxonomony database (ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz)
		- NCBI NR/NT databases (ftp://ftp.ncbi.nlm.nih.gov/blast/db/)
		- The BLASTDB variable must be set in the environmental variables:
		  export BLASTDB=/path/to/NCBI/TaxDB:/path/to/NCBI/NR:/path/to/NCBI/NT
		
NOTE		The NCBI TaxDB, nr and nt databases can be downloaded with the update_blastdb.pl from NCBI
		http://www.ncbi.nlm.nih.gov/blast/docs/update_blastdb.pl

USAGE		${name} \\
		  -t 64 \\
		  -p blastn \\
		  -a megablast \\
		  -d nr \\
		  -q *.fasta \\
		  -e 1e-10 \\
		  -c 1 \\
		  -o RESULTS

OPTIONS:
-p (--program)	BLAST type: blastn, blastp, blastx, tblastn or tblastx [Default: blastn]
-a (--algo)	Blastn algorithm: blastn, dc-megablast, or megablast [Default: megablast] 
-t (--threads)	Number of threads [Default: 16]
-q (--query)	FASTA file(s) to query
-d (--db)	Database to query: nt, nr, or other [Default: nt]
-e (--evalue)	Evalue cutoff [Default: 1e-05]
-c (--culling)	Culling limit [Default: 1]
-g (--gilist)	Restrict search to GI list
-x (--taxids)	Restrict search to taxids from file ## one taxid per line
-n (--ntaxids)	Exclude from search taxids from file ## one taxid per line
-o (--outdir)	Output directory [Default: ./]
OPTIONS
die "\n$usage\n" unless @ARGV;

## Defining options
my $blast_type = 'blastn';
my $task = 'megablast';
my $db = 'nt';
my @query;
my $threads = 16;
my $evalue = 1e-05;
my $culling = 1;
my $gi;
my $taxids;
my $ntaxids;
my $outdir = './';

GetOptions(
    'p|program=s' => \$blast_type,
	'a|algo=s' => \$task,
	'd|db=s' => \$db,
	'g|gilist=s' => \$gi,
	't|threads=i' => \$threads,
	'e|evalue=s' => \$evalue,
	'c|culling=i' => \$culling,
	'q|query=s@{1,}' => \@query,
	'x|taxids=s' => \$taxids,
	'n|ntaxids=s' => \$ntaxids,
	'o|outdir=s' => \$outdir
);

## Checking output directory
unless (-d $outdir){
	make_path ($outdir,{mode => 0755}) or die "Can't create $outdir: $!\n";
}


## Checking for taxonomic restrictions, if any
## Useful to query a subset of the NCBI databases
my $gilist = '';
if ($gi){
	$gilist = "-gilist $gi";
}
my $taxonomic_restrictions = '';
if ($taxids){
	$taxonomic_restrictions = "-taxidlist $taxids";
}
elsif ($ntaxids){
	$taxonomic_restrictions = "-negative_taxidlist $ntaxids";
}

## Running BLAST
my $algo = '';
if ($blast_type eq 'blastn'){ $algo = "-task $task"; }

for my $query (@query){

	my $filename = fileparse($query);
	my ($basename,$extension) = $filename =~ /^(.*)\.(\w+)$/;
	my $outfile = $outdir.'/'.$basename.'.'.$blast_type.'.6';

	print "Running $blast_type on $query against $db using $threads threads. This might take a while...\n";

	system "$blast_type \\
	  -num_threads $threads \\
	  $algo \\
	  -query $query \\
	  -db $db \\
	  $gilist \\
	  $taxonomic_restrictions \\
	  -evalue $evalue \\
	  -culling_limit $culling \\
	  -outfmt '6 qseqid sseqid qstart qend pident length bitscore evalue staxids sscinames sskingdoms sblastnames' \\
	  -out $outfile";
}
