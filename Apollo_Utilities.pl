#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions);

my $name = 'Apollo_Utilities.pl';
my $version = '0.1a';
my $updated = '3/11/21';
my $usage = <<"EXIT";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	The purpose of this script is to increase backend usability for the Apollo annotation software. This single
			script is a one stop location for adding or deleting an organism, loading and unloading user annotations,
			and adding or removing reference tracks.

REQUIRES	GMOD/Apollo (https://github.com/GMOD/Apollo)
			galaxy-genome-annotation/python-apollo (https://github.com/galaxy-genome-annotation/python-apollo)
			\$APOLLO ENV Variable (/path/to/Apollo_distro)

COMMAND		${name} --add_organism \\
			-f cuni.fasta \\
			-g Encephalitozoon \\
			-s cuniculi \\
			-i E_cuni_50602 \\
			-d /media/FatCat/apollo/data/E_cuni_50602 \\
			-b /media/FatCat/apollo/data/E_cuni_50602/TwoBit/E_cuni_50602.2bit

OPTIONS
------------------------------------------------------------------------------------------------------------------------
--add_organism
------------------------------------------------------------------------------------------------------------------------
-f		Assembly fasta file
-g		Genus
-s		Species
-i		Organism ID
-d		Organims data location (apollo/data/orgasnism)
-b		(optional) Blatdb

------------------------------------------------------------------------------------------------------------------------
--delete_organism
------------------------------------------------------------------------------------------------------------------------
-i		Organism ID

------------------------------------------------------------------------------------------------------------------------
--load_annotations
------------------------------------------------------------------------------------------------------------------------
-i		Organism ID
-a		Annotation gff file (needs to be Apollo capatable, can be done with ProdigalGFFtoApolloGFF.pl)

------------------------------------------------------------------------------------------------------------------------
--remove_annotations
------------------------------------------------------------------------------------------------------------------------
-i Organism ID

------------------------------------------------------------------------------------------------------------------------
--add_reference
------------------------------------------------------------------------------------------------------------------------
-a		Track gff file
-t		Track type {CDS;match,match_part;tRNA}
-l		Track label
-d		Organism data location (apollo/data/organism)
-c		Track color

------------------------------------------------------------------------------------------------------------------------
--remove_reference
------------------------------------------------------------------------------------------------------------------------
-l		Track label
-d		Organism data location (apollo/data/organism)

EXIT
die($usage) unless(@ARGV);

my $add_org;
my $rem_org;
my $add_annot;
my $rem_annot;
my $add_ref;
my $rem_ref;

my $fasta;
my $genus;
my $species;
my $org_id;
my $path;
my $blat;
my $gff;
my $type;
my $label;
my $color;

GetOptions(
	'add_organism' => \$add_org,
	'delete_organism' => \$rem_org,
	'load_annotations' => \$add_annot,
	'remove_annotations' => \$rem_annot,
	'add_reference' => \$add_ref,
	'remove_reference' => \$rem_ref,
	'f=s' => \$fasta,
	'g=s' => \$genus,
	's=s' => \$species,
	'i=s' => \$org_id,
	'd=s' => \$path,
	'b=s' => \$blat,
	'a=s' => \$gff,
	't=s' => \$type,
	'l=s' => \$label,
	'c=s' => \$color
);

my $APOLLO = $ENV{'APOLLO'};
die("\$APOLLO enviromental variable not set\n") unless($APOLLO);

if($add_org){
	system("$APOLLO/web-app/jbrowse/bin/prepare-refseqs.pl --fasta $fasta --out $path");
	system("arrow init");
	unless($blat){
		system("arrow organisms add_organism --genus $genus --species $species $org_id $path");
	}
	else{
		system("arrow organisms add_organism --blatdb $blat --genus $genus --species $species $org_id $path");
	}
}

if($rem_org){
	system("arrow init");
	system("arrow organisms delete_features $org_id");
	system("arrow organisms delete_organism $org_id");
}

if($add_annot){
	system("arrow init");
	system("arrow annotations load_gff3 $org_id $gff");
}

if($rem_annot){
	system("arrow init");
	system("arrow organisms delete_features $org_id");
}

if($add_ref){
	if($color){
		system("$APOLLO/web-app/jbrowse/bin/flatfile-to-json.pl --gff $gff --type $type --trackLabel $label --out $path --subfeatureClasses '{\"match_part\": \"$color\"}'");
	}
	else{
		system("$APOLLO/web-app/jbrowse/bin/flatfile-to-json.pl --gff $gff --type $type --trackLabel $label --out $path");
	}
}

if($rem_ref){
	system("$APOLLO/bin/remove-track.pl --trackLabel $label --delete --dir $path");
}