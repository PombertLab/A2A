#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'ContigOrientation.pl';
my $version = '0.5a';
my $updated = '3/21/21';

my $usage = << "EXIT";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	This scirpt is used to determine what orientation a contig is in relation to the existing genome
			in the NCBI database, and reorient if desired.

COMMAND		${name} \\
			-d /media/FatCat/Databases/Ecun \\
			-a E_cuni.assembly.fasta \\
			-c chromosome.log \\
			-r

-a | --assembly		Genome assembly file
-d | --db			Path to reference database
-c | --cclink		chromosome.log file created by IDChromNum.pl (required for -r|--reorient option)
-r | --reorient		Reorient assembly according to consensus [default = off]
-v | --verb			Prints results to STDOUT as well as log file [default = off]

EXIT
die($usage) unless(@ARGV);

my $assembly;
my $db;
my $cclink;
my $reorient;
my $v;

GetOptions(
	'a|assembly=s' => \$assembly,
	'd|db=s' => \$db,
	'c|cclink=s' => $cclink,
	'r|reorient' => \$reorient,
	'v|verb' => \$v
);

## Get database name from directory name
my $db_name;
if($db =~ /.+?\/(.+)/){
	$db_name = $1;
}

## Run blastp on assembly using given database
system("blastp \\
		-query $assembly \\
		-db $db_name \\
		-culling_limit 1 \\
		-outfmt 6 \\
		-out proteins.blastp.6
");

open BP,"<","proteins.blastp.6";
my $prev_contig;
my $current_contig;
my $prev_accession_number;
my $prefix;
my %orientation;

## Parsing the protein blast file
while (my $line = <BP>){
	chomp($line);
	my $current_accession_number;
	my @info = split("\t",$line);
	my $contig_info = $info[0];
	my $accession_info = $info[1];
	if($contig_info =~ /^(\w+?)_(\w+?)_/) { $prefix = $1; $current_contig = $2; }
	if($contig_info =~ /^(\w+?)_(\w+_\d+)_\d+/) {$prefix = $1; $current_contig = $2; }
	if($accession_info =~ /^\w+?_(\d+)\./) { $current_accession_number = $1 + 0; }
	unless($prev_contig) { $prev_contig = $current_contig; $prev_accession_number = $current_accession_number; next; }
	## Count the amount of proteins that are in increasing order (same orientation), in decreasing order (oppisite 
	## oritentation), or nonsense order (inconclusive)
	if ($current_accession_number eq $prev_accession_number+1){
			if($orientation{$current_contig}{'+'}) { $orientation{$current_contig}{'+'}++; }
			else { $orientation{$current_contig}{'+'} = 1; }
		}
		elsif ($current_accession_number eq $prev_accession_number-1){
			if($orientation{$current_contig}{'-'}) { $orientation{$current_contig}{'-'}++; }
			else { $orientation{$current_contig}{'-'} = 1; }
		}
		else{
			if($orientation{$current_contig}{'?'}) { $orientation{$current_contig}{'?'}++; }
			else { $orientation{$current_contig}{'?'} = 1; }
		}
	$prev_accession_number = $current_accession_number;
}

## Populate chromosone-contig relationship
my %links;
if($cclink){
	open LINK,"<","$cclink";
	while (my $line = <LINK>){
		my @linfo = split("\t",$line);
		my $con = $linfo[0]; my $some = $linfo[1]; my $percent = $linfo[2];
		if($linfo[2] < 50){ $links{$con} = "Unidentified"; }
		else { $links{$con} = $some; }
	}
}

## Iterating over protein orientation to get a consensus of the orientation of the contig
my %sigil_key = ("+"=>"Forward","-"=>"Reverse Complement","?"=>"Inconclusive");
my %consensus;
open LOG,">","${prefix}_orientation.log";
open LOG2,">","${prefix}_orientation_consensus.log";
foreach my $contig_key (sort keys %orientation){
	if($v) { print "\n"; }
	print LOG2 ">${prefix}_$contig_key\n";
	my $max_num=0;
	my $total=0;
	my $max_key;
	foreach my $orientation_key (sort keys %{$orientation{$contig_key}}){
		if ($v) { print "${prefix}: $contig_key\tOrientation: $orientation_key\t\tCount: $orientation{$contig_key}{$orientation_key}\n"; }
		print LOG2 "$orientation_key\t$orientation{$contig_key}{$orientation_key}\n";
		my $count = $orientation{$contig_key}{$orientation_key};
		if ($count > $max_num){ $max_key = $orientation_key; $max_num = $count }
		$total += $count;
	}
	$consensus{$contig_key} = $max_key;
	my $percentage = sprintf("%.2f",$max_num/$total*100);

	if ($v) { print "There is a $percentage% chance that ${prefix} ${contig_key}'s orientation is $sigil_key{$max_key}\n"; }
	print LOG "${prefix}_${contig_key}\t$sigil_key{$max_key}\n";
}

## Reorienting reverse complement contigs
$current_contig = ();
my %orientation_corrections;
if($reorient&&$cclink){
	## Populating strings of contig sequences
	open FAST,"<","${reorient}";
	open LOG3,">","${prefix}_reorientation.log";
	while (my $line = <FAST>){
		chomp($line);
		## Looking for start of new contig
		if ($line =~ /^>\w+?_(\w+\d+)/) { $current_contig = $1; next; }
		if ($line =~ /^>\w+?_(\w+)/) { $current_contig = $1; next; }
		if ($orientation_corrections{$current_contig}) { $orientation_corrections{$current_contig} .=  $line; }
		else { $orientation_corrections{$current_contig} = $line; }
	}
	## Reorienting contig sequences
	open FOUT,">","reoriented.fasta";
	foreach my $contig_key (sort keys %orientation_corrections){
		my $line = $orientation_corrections{$contig_key};
		my $length = length($line);
		my $some = $links{"${prefix}_${contig_key}"};
		print FOUT ">${prefix}_${contig_key} [chromosome = $some] [length = ${length} bp]\n";
		if (exists $consensus{$contig_key}) {
			if ($consensus{$contig_key} eq "-"){
				$line = reverse($line);
				$line =~ tr/AaCcGgTtRrYyKkMmBbVvDdHh/TtGgCcAaYyRrMmKkVvBbHhDd/;
				print LOG3 "${prefix}_$contig_key reoriented\n";
			}
		}
		my @seq = unpack("(A60)*",$line);
		while (my $seq_line = shift(@seq)) { print FOUT "$seq_line\n"; }
	}
}