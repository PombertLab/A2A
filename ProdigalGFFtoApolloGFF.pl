#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = 'ProdigalGFFtoApolloGFF.pl';
my $version = '0.1a';
my $updated = '3/8/21';
my $usage = <<"EXIT";
NAME        ${name}
VERISON     ${version}
UPDATED     ${updated}
SYNOPSIS	This script takes the gff output by hyattpd/prodigal gene prediction software and converts it into a 
			GMOD/apollo compatible gff3 file that can be readily loaded as a user annotation

COMMAND     ${name} -i *.gff

OPTIONS

-i | --in    Prodigal gff3 file

EXIT
die("$usage\n") unless(@ARGV);

my @in;
GetOptions(
    'i|in=s@{1,}' => \@in
);

my @type = ('mRNA','exon');
foreach my $file (@in){
    open IN,"<","$file";
    my ($filename,$dir) = fileparse($file);
    open OUT,">","$dir/$filename.apollo.gff3";
    while (my $line = <IN>){
        chomp($line);
        my @info = split("\t",$line);
        my @data = split(";",$info[-1]);
        my @ID = ("$data[0]_mRNA;","$data[0]_exon;Parent=$data[0]_mRNA;");
        my @print = (@info[0..1],\@type,@info[3..7]);
        $ID[-1] =~ s/Parent=ID=/Parent=/;
        for (my $i = 0; $i < 2; $i++){
            for (my $j = 0; $j < 8; $j++){
                if ($j != 2) { print OUT "$print[$j]\t"; }
                else { print OUT "$print[$j][$i]\t"; }
            }
            print OUT "$ID[$i]\n";
        }
    }
    close IN;
}