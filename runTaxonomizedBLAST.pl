#!/usr/bin/perl
## Pombert Lab, IIT 2019
my $name = 'runTaxonomizedBLAST.pl';
my $version = '0.3';
my $update = '2/6/2021';

use strict; use warnings; use Getopt::Long qw(GetOptions);

my $usage = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Runs taxonomized BLAST searches, and returns the outfmt 6 format with columns staxids, sscinames, sskingdoms, and sblastnames
REQUIREMENTS	- BLAST 2.2.28+ or later
		- NCBI taxonomony database (ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz)
		- NCBI NR/NT databases (ftp://ftp.ncbi.nlm.nih.gov/blast/db/)
		- The BLASTDB variable must be set in the environmental variables:
		  export BLASTDB=/path/to/NCBI/TaxDB:/path/to/NCBI/NR:/path/to/NCBI/NT
		
NOTE		The NCBI TaxDB, nr and nt databases can be downloaded with the update_blastdb.pl from NCBI
			https://www.ncbi.nlm.nih.gov/IEB/ToolBox/CPP_DOC/lxr/source/src/app/blast/update_blastdb.pl

USAGE		runTaxonomizedBLAST.pl \\
		-t 64 \\
		-p blastn \\
		-a megablast \\
		-d nt \\
		-q *.fasta \\
		-e 1e-10 \\
		-c 1
OPTIONS:
-t (--threads)	## Number of threads [Default = 16]
-p (--program)	## BLAST type: blastn, blastp, blastx, tblastn or tblastx [Default = blastn]
-a (--algo)	## Blastn algorithm: blastn, dc-megablast, or megablast [Default = megablast] 
-d (--db)	## Database to query: nt, nr, or other [Default = nt]
-g (--gilist)	## Restrict search to GI list
-q (--query)	## FASTA file(s) to query
-e (--evalue)	## Evalue cutoff [Default = 1e-05]
-c (--culling)	## Culling limit [Default = 1]
OPTIONS
die "$usage\n" unless @ARGV;
## Defining options
my $blast_type = 'blastn';
my $task = 'megablast';
my $db = 'nt';
my $gi;
my $threads = 16;
my $evalue = 1e-05;
my $culling = 1;
my @query;

GetOptions(
    'p|program=s' => \$blast_type,
	'a|algo=s' => \$task,
	'd|db=s' => \$db,
	'g|gilist=s' => \$gi,
	't|threads=i' => \$threads,
	'e|evalue=s' => \$evalue,
	'c|culling=i' => \$culling,
	'q|query=s@{1,}' => \@query
);

## Running BLAST
my $algo = ''; if ($blast_type eq 'blastn'){$algo = "-task $task";}
my $list = ''; if ($gi){$list = "-gilist $gi";}
for my $query (@query){
	system "$blast_type".
		" -num_threads $threads".
		" $algo".
		" -query $query".
		" -db $db".
		" $list".
		" -evalue $evalue".
		" -culling_limit $culling".
		" -outfmt '6 qseqid sseqid qstart qend pident length bitscore evalue staxids sscinames sskingdoms sblastnames'".
		" -out $query.$blast_type.6";
}