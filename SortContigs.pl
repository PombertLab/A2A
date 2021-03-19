#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'SortContigs.pl';
my $version = '0.2b';
my $updated = '3/13/21	File Handling Rework';
my $usage = << "USAGE";
NAME        ${name}
VERSION     ${version}
UPDATED     ${updated}
SYNOPSIS    Keeps longest contigs of an <assembly>.fasta file

COMMAND     ${name} -mn 5000 -i assembly.fasta -v

-mn | --min     Minimum size of contigs [default=1k]
-mx | --max     Maximum size of contigs
-i  | --in      Name of input file
-v  | --verb    Print the first -n bases and last -n bases 
-n  | --num     Number of bases to be printed [default=50]
USAGE
die "\n$usage\n" unless(@ARGV);
my $in;
my $d_min = 1;
my $d_max;
my $verb;
my $num = 50;
GetOptions(
    'mn|min=i' => \$d_min,
    'mx|max=i' => \$d_max,
    'i|in=s' => \$in,
    'v|verb' => \$verb,
    'n|num' => \$num 
);

my $min = 1000*$d_min;
my $max;
if($d_max) { $max = 1000*$d_max; }

my $out = "sorted.fasta";
my $rout = "removed.fasta";

open IN, "<", "$in";
open OUT, ">", "$out";
open RM, ">", "$rout";

my %contigs;
my @names;
my $key;
while (my $line = <IN>){
    chomp($line);
    if ($line =~ /^>(\w+)/){
        $key = $1;
        push(@names,$key);
    }
    else{ $contigs{$key} .= $line; }
}
while (my $cg = shift(@names)){
    my $len = length($contigs{$cg});
    if ($len >= $min){
        print OUT ">$cg\n";
        my @seq = unpack("(A60)*",$contigs{$cg});
        if ($verb){
            print "$cg; length = $len bp\n";
            my $start; my $end;
            if ($contigs{$cg} =~ /^(\w{$num}).*(\w{$num})$/){ $start = $1; $end = $2; }
            print "START = $start\nEND   = $end\n\n";
        }
        while (my $seq = shift(@seq)){ print OUT "$seq\n" }
    }
    else{
        print RM ">$cg\n";
        my @seq = unpack("(A60)*",$contigs{$cg});
        while (my $seq = shift(@seq)){ print RM "$seq\n" }
    }
}