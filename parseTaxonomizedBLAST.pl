#!/usr/bin/perl
## Pombert Lab, IIT 2019
my $name = 'parseTaxonomizedBLAST.pl';
my $version = '0.2';
my $update = '2/6/2021';

use strict; use warnings; use Getopt::Long qw(GetOptions);

my $usage = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Parses the content of taxonomized BLAST searches
REQUIREMENT	-outfmt '6 qseqid sseqid qstart qend pident length bitscore evalue staxids sscinames sskingdoms sblastnames'
USAGE		parseTaxonomizedBLAST.pl \\
		-b *.outfmt.6 \\
		-f *.fasta \\
		-n Streptococcus 'Streptococcus suis' 'Streptococcus sp.'
		-e 1e-25 \\
		-o output.fasta
		-v
OPTIONS:
-b (--blast)	## BLAST input file(s)
-f (--fasta)	## FASTA file(s)
-n (--name)		## Names to be queried
-i (--inverse)	## Returns queries NOT matching specified names
-c (--column)	## Which columns to query: sscinames, sskingdoms or sblastnames [Default: sscinames] 
-e (--evalue)	## Evalue cutoff for target organism(s) [Default: 1e-10]
-o (--output)	## FASTA output file containing the desired sequences
-k (--keep)		## Keep non-BLASTed Sequences 
-v (--verbose)	## Verbose [Default: off]
OPTIONS
die "$usage\n" unless @ARGV;

my @blast;
my @fasta;
my @target;
my $inverse;
my $column = 'sscinames';
my $evalue = 1e-10;
my $output;
my $keep;
my $verbose;
GetOptions(
	'b|blast=s@{1,}' => \@blast,
	'f|fasta=s@{1,}' => \@fasta,
	'n|name=s@{1,}' => \@target,
	'i|inverse' => \$inverse,
	'c|column=s' => \$column,
	'e|evalue=s' => \$evalue,
	'o|output=s' => \$output,
	'k|keep' => \$keep,
	'v|verbose' => \$verbose
);

unless (($column eq 'sscinames')||($column eq 'sskingdoms')||($column eq 'sblastnames')){
	die "\nError. Column name $column is not recognised.\nPlease use either sscinames, sskingdoms or sblastnames\n\n";
}

## Creating db of sequences from FASTA files
my %sequences;
for my $fasta (@fasta){
	open FASTA, "<$fasta";
	my $name;
	while (my $line = <FASTA>){
		chomp $line;
		if ($line =~ /^>(\S+)/){$name = $1;}
		else {$sequences{$name} .= $line;}
	}
}

## Creating db of names to search for
my %scinames; for my $names (@target){$scinames{$names} = $name;}

## Parsing BLAST 'outfmt 6' file(s)
my %blasts;
while (my $blast = shift@blast){
	open BLAST, "<$blast";
	while (my $line = <BLAST>){
		chomp $line;
		my @columns = split("\t", $line);
		my $query = $columns[0]; my $bitscore = $columns[6]; my $ev = $columns[7];
		## Columns; [0] query, [1] target, [2] qstart, [3] qend, [4] pident, [5] length, 
		## [6] bitscore, [7] evalue, [8] taxid, [9] sciname, [10] kingdom, [11] blastname
		unless ($ev <= $evalue){next;}
		if (exists $blasts{$blast}{$query}){
			if ($bitscore > $blasts{$blast}{$query}[6]){ ## Checking for better hit(s) based on bitscores
				for (0..$#columns){$blasts{$blast}{$query}[$_] = $columns[$_];}
			}
		}
		else{for (0..$#columns){$blasts{$blast}{$query}[$_] = $columns[$_];}}
	}
}

## Outputting sequences based on BLAST name matches/non-matches, and if 'keep' is flagged, keep
## sequences that have no BLAST results to prevent possible genetic information loss
my %kept = %sequences;
open OUT,">","$output";
my @blasts = sort (keys %blasts);
for my $blast (@blasts) { ## For each BLASTed file
    for my $query (sort (keys %{$blasts{$blast}})){ ## For each BLASTed contig
		my $regex;
		## Define which column to search names in
		if ($column eq 'sscinames'){$regex = $blasts{$blast}{$query}[9];}
		elsif ($column eq 'sskingdoms'){$regex = $blasts{$blast}{$query}[10];}
		elsif ($column eq 'sblastnames'){$regex = $blasts{$blast}{$query}[11];}
		if ($verbose){print "Best hit for $query = $regex\n";}
		my @names = keys %scinames;
		# my $flag = undef;
		for my $name (@names){ ## For each name that was given to search for
			if ($regex =~ /$name/i){ ## If the name matches
				if($inverse){ ## And we are keeping non-matching sequences
					delete $kept{$query}; ## Delete the matching sequence
					next;
				}
				else{ ## And we are keeping matching sequences, print them to file
					if ($verbose){
						print "Match found for $name: ";
						print "@{$blasts{$blast}{$query}}\n";
					}
					unless($keep){
						print OUT ">$query\n";
						my @seq = unpack ("(A60)*", $sequences{$query});
						while (my $tmp = shift@seq){print OUT "$tmp\n";}
					}
					last; ## If a name matches, check next contig
				}
			}
			else{ ## If the name doesn't match
				if($inverse){ ## And we are keeping non-matching sequences, print to file
					if ($verbose){
						print "Match different from $name: ";
						print "@{$blasts{$blast}{$query}}\n";
					}
					unless($keep){
						print OUT ">$query\n";
						my @seq = unpack ("(A60)*", $sequences{$query});
						while (my $tmp = shift@seq){print OUT "$tmp\n";}
					}
					last; ## If a name is different, check next contig
				}
				else{ ## And we are keeping matching sequences
					delete $kept{$query}; ## Delete non-matching sequence
				}
			}
		}
	}
}
if($keep){
	for my $query (sort keys %kept){
		print OUT ">$query\n";
		my @seq = unpack ("(A60)*", $sequences{$query});
		while (my $tmp = shift@seq){print OUT "$tmp\n";}
	}
}