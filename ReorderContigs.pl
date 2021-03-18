#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'ReorderContigs.pl';
my $version = '0.1';
my $updated = '2/15/2021';
my $usage = <<"EXIT";

NAME        ${name}
VERSION     ${version}
UPDATED     ${updated}
SYNOPSIS    This script sorts contigs by sequence length (longest to shortest) 
            and renames them accordingly.

COMMAND     ${name} -i E_hel.spades_assembly.fasta

USAGE

-i | --in       Fasta assembly file

EXIT

die($usage)unless(@ARGV);

my $in;

GetOptions(
    "i|in=s" => \$in
);

die("[E] Input assembly fasta file not provided") unless($in);

open IN,"<",$in;
open OUT,">","reordered.fasta";

## Parse sequences from fasta assembly file
my $contig;
my %sequences;
while(my $line = <IN>){
    chomp($line);
    if($line =~ /^>(\S+?_\d+)/){
        $contig = $1;
        next;
    }
    $sequences{$contig} .= $line;
}

## Calculating number of padding zeros
my $nos = scalar(keys %sequences);
my $width = length($nos);

## Get the length of the contig sequences
my %order;
foreach my $key (keys %sequences){
    my $len = length($sequences{$key});
    $order{$key} = $len;
}

## Print contig sequences from largest to smallest
my $contig_num = sprintf("%0${width}d", 1);
foreach my $key (sort { $order{$b} <=> $order{$a}} keys %order){
    my $len = length($sequences{$key});
    print OUT ">contig_$contig_num [length = $len bp]\n";
    my @seq = unpack("(A60)*",$sequences{$key});
    while (my $val = shift(@seq)){
        print OUT "$val\n";
    }
    $contig_num++;
}