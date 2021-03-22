# A2A - Assembly to Annotations

The A2A pipeline was designed as a precursor pipeline to the [A2GB](https://github.com/PombertLab/A2GB) pipeline.

The A2A pipeline takes a user through the process of cleaning an assembly, orienting its contigs against a reference, predicting genes using [Prodigal](https://github.com/hyattpd/Prodigal), creating annotation references using [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download) homology searches, and uploading the final genome assembly, annotation references, and gene predictions to [Apollo](https://github.com/GMOD/Apollo) for annotation purposes.

## Table of Contents

- [Requirements](#Requirements)
- [Pipeline Process](#Pipeline-Process)
	- [Cleaning Raw Assembly](#Cleaning-Raw-Assembly)
		- [Identify and Parse Contaminants](#Identify-and-Parse-Contaminants)
		- [Size Select, Reorder, and Rename](#Size-Select,-Reorder,-and-Rename)
	- [Matching Against a Reference Genome](#Matching-Against-a-Reference-Genome)
		- [Obtain NCBI Organism Data](#Obtain-NCBI-Organism-Data)
		- [Chromosome Consensus Creation](#Chromosome-Consensus-Creation)
		- [Contig Reorientation](#Contig-Reorientation)
	- [Prepare Apollo for Annotations](#Prepare-Apollo-for-Annotations)
		- [Creating an Organism](#Creating-an-Organism)
		- [Create and Load Prediction Data as Annotations](#Create-and-Load-Prediction-Data-as-Annotations)
		- [Create and Load References](#Create-and-Load-References)
- [Literature](#Literature)

## Requirements

- [PERL5](https://www.perl.org/)
- [NCBI BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/)
- [Python3](https://www.python.org/downloads/)
	- [Selenium](https://pypi.org/project/selenium/)
	- [arrow](https://pypi.org/project/arrow/)
	- [apollo](https://python-apollo.readthedocs.io/en/latest/README.html)
- [Python3-devel](https://pkgs.org/download/python3-devel)
- [Apollo](https://genomearchitect.readthedocs.io/en/latest/)

## Pipeline Process

First, let's prepare our working environment by creating a variable that points to the location of the raw assembly.


```bash
export ASSEMBLY=/path/to/raw_assembly
```

### Cleaning Raw Assembly

#### Identify and Parse Contaminants

The first step in cleaning our raw assembly is identifying which contig(s) belong to the organism that is being analyzed. Contaminants are identified by a sequence homology search utilizing NCBI's [BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/) suite. Next, the contaminants are parsed out of the assembly file.

We identify contaminants in the assembly with the following command:

```bash
runTaxonomizedBLAST.pl \
	-t 64 \
	-p blastn \
	-a megablast \
	-d nt \
	-q $ASSEMBLY/<raw_assembly>.fasta \
	-e 1e-10 \
	-c 1
```

This command runs a BLAST homology search on the specified assembly at the nucleotide level [-p blastn] using the non-redundant database [-d nt], with an error value cutoff of 1e-10 [-e 1e-10], and a culling limit of 1 [-c 1]. The reason we set a culling limit of 1 is because we want only the BEST match.

We remove contaminants from the assembly with the following command:

```bash
parseTaxonomizedBLAST.pl 
	-b $ASSEMBLY/*.outfmt.6 \
	-f $ASSEMBLY/<raw_assembly>.fasta \
	-n "organism of interest 1" "organism of interest 2"
	-e 1e-10 \
	-o $ASSEMBLY/parsed.fasta
```

#### Size Select, Reorder, and Rename

The next step in cleaning our raw assembly is removing contigs smaller than a desired cutoff, sorting contigs from longest to shortest, and thusly renaming the contigs to match their new placement in the assembly file.

We size select contigs from assemblies with the following command:

```bash
SizeSelectContigs.pl \
	-i $ASSEMBLY/parsed.fasta \
```

Options for SortContigs.pl  are:

```bash
-i  | --in      Name of input file
-mn | --min     Minimum size of contigs [default=1k]
-mx | --max     Maximum size of contigs
```

We reorder and rename contigs from assemblies with the following command:

```bash
ReorderContigs.pl \
	-i $ASSEMBLY/size_selected.fasta
```

### Matching Against a Reference Genome

In order to determine the contig-chromosome relationship in our assembly, a reference is needed. Our pipeline was built around [NCBI datasets](https://ftp.ncbi.nlm.nih.gov/refseq/release/) and assumes that the selected reference has a chromosome assignment. The selected reference will be used to identify whether our contigs are in the _same_ or _reverse complement_ orientation compared to the reference. If necessary, our data will be reoriented to match the selected reference.

#### Obtain NCBI Organism Data

For each reference assembly in NCBI, exists a plethora of useful data files. Of the most interest to us will be the files that contain the genome, proteins and RNA sequences, and the reference feature table. The sequence files will be used to create BLAST databases for genome comparisons. The feature table contains accession numbers for chromosomes.

These files and databases can be obtained and created using the following command:

```bash
GetOrganismData.py \
	-k "kingdom" \
	-g "genus" \
	-s "species" \
	-p "/desired/path/for/database/creation"
```

To ease the following steps, let's create a database enviroment variable:

```bash
export DATABASE="/path/to/created/database"
```

This variable will point to the location of where GetOrganismData.py stored our NCBI files and reference databases. The GetOrganismData.py command will place files in a directory that is named using the first letter of the genus and the first three letters of the species.

For example:

```bash
- Encephalitozoon cuniculi --> Ecun
```

#### Chromosome Consensus Creation
Our pipeline uses protein homology searches to perform chromosome assignments. The first step in the consensus creation is obtaining a list of predicted proteins from our genome. In the case of Microsporidia, we use the [Prodigal](https://github.com/hyattpd/Prodigal) gene prediction tool.

We can predict proteins with Prodigal as follows:

```bash
prodigal \
	-i $ASSEMBLY/reordered.fasta \
	-c \
	-a $ASSEMBLY/proteins.fasta
```

Each protein is tied to an accession number that is unique to a chromosome. For each contig, we count the number of proteins that are tied to the different chromosomes accession numbers of the organism, creating our consensus.

The chromosome consensus can be obtained by running the following command:

```bash
IDChromNum.pl \
	-f $ASSEMBLY/reordered.fasta \
	-p $ASSEMBLY/proteins.fasta \
	-d $DATABASE
```

#### Contig Reorientation

To determine orientation and reorient when necessary, we run the following command:

```bash
ContigOrientation.pl \
	-a $ASSEMBLY/chromo.fasta \
	-c $ASSEMBLY/chromosome.log \
	-d $DATABASE \
	-r
```

The possible outcomes are as follows.
- If the number of 5'->3' reads is greater than the number of 3'->5' and non-sense reads
	- The contig matches NCBI's orientation and does not require reorientation. 
- If the number of 3'->5' reads is greater than the number of 5'->3' and non-sense reads
	- The contig is Reverse Complimentary to NCBI's, and needs to be reoriented. 
- If the number of non-sense reads is greater than the number of 5'->3' and 3'->5' reads
	- Analyze assembly on a deeper level to determine what is going on.

Each protein has a unique accession number, n. The protein previous on the 5' side has an accession number of n-1 and the protein latter on the 3' side has an accession number of n+1. The difference between accession numbers along the contig is determined, and are sorted into three categories: n+1 (5'->3'), n-1 (3'->5'), and all other differences non-sense. 

### Prepare Apollo for Annotations

We will now prepare our [Apollo](https://genomearchitect.readthedocs.io/en/latest/) enviroment for the annotation process by:
- creating an organism and uploading genome data to Apollo
- creating and loading predicted proteins to Apollo as annotations
- creating evidence based annotations using sequence homology searches on references
- loading evidence based annotations as comparisons

First we are going to create a directory where our organism data for Apollo will be stored.

```bash
mkdir /path/to/apollo/organism/data
```

Next we are going to create an enviroment variable that points there.

```bash
export $APOLLO_DATA = /path/to/apollo/organism/data
```

It is good practice to have your directory name match the ID you will give your organism in the next step for simplicity of use.

#### Creating an Organism

To annotate our organism, we first need to create an instance of it on Apollo.

```bash
Apollo_Utilities.pl --add_organism \
-f $ASSEMBLY/reoriented.fasta \
-g "Genus of organism" \
-s "Species of organism" \
-i "User-defined ID of organism" \
-d $APOLLO_DATA
```

If you have not yet initiallized your arrow tool by running `arrow init`, you will be prompted to sign in so arrow can access your Apollo account.

#### Create and Load Prediction Data as Annotations

Now we must get a new set of protein predictions based off the assembly that was reoriented to match the selected reference.

```bash
prodigal \
	-i $ASSEMBLY/reoriented.fasta \
	-c \
	-f gff \
	-o $ASSEMBLY/proteins.reoriented.gff
```

We want the predictions to be in GFF format, as it is the required format for Apollo user loaded annotations, so the format flag is passed gff [-f gff].


```bash
SizeSelectGFF3.pl \
	-g $ASSEMBLY/proteins.reoriented.gff \
	-n 60
```

Not all protein predictions will be found in our organism or reference(s). Proteins smaller than a given number of amino acids could be concidered low confidence, and be removed from the file we want to load as is the case in the SizeSortGFF3.pl command, where proteins under 60 amino acids are removed [-n 60].

Next, Apollo requires a specific gff format that differs from that produced by [Prodigal](https://github.com/hyattpd/Prodigal), so we must reformat Prodigal's gff using the following command:

```bash
ProdigalGFFtoApolloGFF.pl \
	-i $ASSEMBLY/proteins.reoriented_large.gff
```

Now we upload the reformatted gff file as user-loaded annotations.

```bash
Apollo_Utilities.pl --load_annotations \
	-i "Organism ID" \
	-a $ASSEMBLY/proteins.reoriented_large.gff.apollo.gff3
```

By uploading protein predictions we will only need to manually add or remove a small amount of annotations to our organism reducing annotation time.

#### Create and Load References

Reference annotations will allow us to assess the validity of protein predictions that we loaded as user annotations, as well as help identify the presence of introns, untraslated transcription regions (UTRs), or broken reading frames.

First, we want to create a directory to keep track of selected reference(s) files and a directory for the local BLAST database.

```bash
mkdir $ASSEMBLY/BLAST; mkdir $ASSEMBLY/BLAST/DB;
```

Next, we want to make a database from the reoriented assembly that the selected references can be compared to.

```bash
makeblastdb \
	-in $ASSEMBLY/reoriented.fasta \
	-dbtype nucl \
	-out $ASSEMBLY/BLAST/DB/"db_name"
```

Next, we want to check sequence homology between the studied organism and the selected reference(s).

```bash
tblastn \
	-num_threads 32 \
	-query $DATABASE/"reference_genome"/"protein.faa" \
	-db $ASSEMBLY/BLAST/DB/"db_name" \
	-evalue 1e-05 \
	-outfmt 6 \
	-out $ASSEMBLY/BLAST/"reference.tblastn.6"
```

Now we have to convert the sequence homology search to gff format so it can be added to Apollo.

```bash
BLAST2GFF3.pl \
	-i $ASSEMBLY/BLAST/"reference.tblastn.6" \
	-f $DATABASE/"reference_genome"/"protein.faa"
```

Finally we are able to add the reference gff to Apollo for comparison purposeses, with the following command:

```bash
Apollo_Utilities.pl --add_reference \
	-a $ASSEMBLY/BLAST/"reference.gff" \
	-t match,match_part \
	-l "track label" \
	-d $APOLLO_DATA
```

This step can repeated for as many references, tRNAs, rRNAs, and others, that Apollo will accept.

## Literature

Altschul SF, Gish W, Miller W, Myers EW, Lipman DJ. **Basic local alignment search tool.** *J Mol Biol.* 1990 Oct 5;215(3):403-10. doi: [10.1016/S0022-2836(05)80360-2](https://doi.org/10.1016/s0022-2836(05)80360-2). PMID: 2231712.

Hyatt, D., Chen, GL., LoCascio, P.F. et al. **Prodigal: prokaryotic gene recognition and translation initiation site identification.** BMC Bioinformatics 11, 119 (2010). doi: [10.1186/1471-2105-11-119](https://doi.org/10.1186/1471-2105-11-119)

Barrett T, Clark K, Gevorgyan R, Gorelenkov V, Gribov E, Karsch-Mizrachi I, Kimelman M, Pruitt KD, Resenchuk S, Tatusova T, Yaschenko E, Ostell J. **BioProject and BioSample databases at NCBI: facilitating capture and organization of metadata.** 
*Nucleic Acids Res.* 2012 Jan;40(Database issue):D57-63. doi: [10.1093/nar/gkr1163](https://doi.org/10.1093/nar/gkr1163). Epub 2011 Dec 1. PMID: 22139929; PMCID: PMC3245069.

Dunn NA, Unni DR, Diesh C, Munoz-Torres M, Harris NL, Yao E, Rasche H, Holmes IH, Elsik CG, Lewis SE. **Apollo: Democratizing genome annotation.** *PLoS Comput Biol.* 2019 Feb 6;15(2):e1006790. doi: [10.1371/journal.pcbi.1006790](https://doi.org/10.1371/journal.pcbi.1006790). PMID: 30726205; PMCID: PMC6380598.