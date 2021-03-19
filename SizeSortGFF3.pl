#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'SizeSortGFF3.pl';
my $version = '0.2a';
my $updated = '3/18/21	File handling rework';
my $usage = <<"EXIT";

NAME        ${name}
VERSION     ${version}
UPDATED     ${updated}
SYNOPSIS    This script parses an assembly gff and seperates genes by size in to two files:
            one for genes smaller than a given threshold, and one for genes larger than or equal 
            to a given threshold.

COMMAND     ${name}

OPTIONS

-g | --gff      Input gff file
-n | --aanum    Amino acid number threshold [default = 100 aa]

EXIT

die($usage) unless(@ARGV);

my $gff;
my $aa = 100;

GetOptions(
    "g|gff=s" => \$gff,
    "n|aanum=i" => \$aa
);
my $ext;
if ($gff =~ /(\.\w+)$/) { $ext = $1; }

## Determing the threshold basepair number
my $bp = $aa * 3 + 3;

## GFF file index values for start and stop bp#
my $start_index = 3;
my $end_index = 4;

my ($filename,$dir) = fileparse($gff);
my $basename = basename($filename,$ext);

open IN,"<","$gff";
open SOUT,">","${dir}/${basename}_small${ext}";
open LOUT,">","${dir}/${basename}_large${ext}";

while(my $line = <IN>){
    chomp($line);
    if($line =~ /^#/) { next; }
    my @gff = split("\t",$line);
    my $length = (abs($gff[$end_index]-$gff[$start_index])+1);
    if($length >= $bp){
        print LOUT "$line\n"; }
    else {
        print SOUT "$line\n"; 
    }
}