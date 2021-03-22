#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'SizeSelectContigs.pl';
my $version = '0.2c';
my $updated = '3/21/2021';
my $usage = << "USAGE";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Keeps longest contigs of an <assembly>.fasta file

COMMAND		${name} \\
			-i assembly.fasta \\
			-mn 5000

-i  | --in		Fasta file to sort
-mn | --min		Minimum size of contigs [default=1k]
-mx | --max		(Optional) Maximum size of contigs
USAGE
die "\n$usage\n" unless(@ARGV);
my $in;
my $min = 1;
my $max;
GetOptions(
	'mn|min=i' => \$min,
	'mx|max=i' => \$max,
	'i|in=s' => \$in
);

## Check if kilo prefix is based in, and remove it and multiply by 1000 if necessary
if($max =~ /k/){
	$max =~ s/k//;
	$max *= 1000; 
}
if($min =~ /k/){
	$min =~ s/k//;
	$min *= 1000;
}

my $out = "size_selected.fasta";
my $rout = "removed.fasta";

open IN, "<", "$in";
open OUT, ">", "$out";
open RM, ">", "$rout";

my %contigs;
my @names;
my $key;
## Populate contig databases with contig sequences
while (my $line = <IN>){
	chomp($line);
	if ($line =~ /^>(\w+)/){
		$key = $1;
		push(@names,$key);
	}
	else{ $contigs{$key} .= $line; }
}
## Check contig sequence length. If greater or equal to the given cutoff, keep the contig, if less than the given cutoff
## sort the contig into the removed file
while (my $cg = shift(@names)){
	my $len = length($contigs{$cg});
	if ($len >= $min){
		print OUT ">$cg\n";
		my @seq = unpack("(A60)*",$contigs{$cg});
		while (my $seq = shift(@seq)){ print OUT "$seq\n" }
	}
	else{
		print RM ">$cg\n";
		my @seq = unpack("(A60)*",$contigs{$cg});
		while (my $seq = shift(@seq)){ print RM "$seq\n" }
	}
}