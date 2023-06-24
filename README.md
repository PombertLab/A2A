#### <b>Version: 0.2.2</b>
#### <b>Updated: 2023-06-23</b>

# A2A - Assembly to Apollo Annotations

The A2A pipeline was designed as a precursor pipeline to the [A2GB](https://github.com/PombertLab/A2GB) pipeline.

The A2A pipeline takes a user through the process of cleaning an assembly, orienting its contigs against a reference, predicting genes using [Prodigal](https://github.com/hyattpd/Prodigal), creating annotation references using [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download) homology searches, and uploading the final genome assembly, annotation references, and gene predictions to [Apollo](https://github.com/GMOD/Apollo) for annotation purposes.

## Table of Contents

- [Requirements](#Requirements)
- [Pipeline Process](#Pipeline-Process)
	- [Cleaning Raw Assembly](#Cleaning-Raw-Assembly)
		- [Size Selection](#Size-Selection)
		- [Identify and Remove Contaminants](#Identify-and-Remove-Contaminants)
	- [Prepare Apollo for Annotations](#Prepare-Apollo-for-Annotations)
		- [Creating an Organism](#Creating-an-Organism)
		- [Create and Load Prediction Data as Annotations](#Create-and-Load-Prediction-Data-as-Annotations)
		- [Create and Load References](#Create-and-Load-References)
- [Literature](#Literature)

## Requirements

- [PERL5](https://www.perl.org/)
- [NCBI BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/)
	- [Non-Redundant Nucleotide Database](https://www.ncbi.nlm.nih.gov/books/NBK62345/#blast_ftp_site.The_blastdb_subdirectory)
- [Python3](https://www.python.org/downloads/)
	- [apollo](https://github.com/galaxy-genome-annotation/python-apollo)
- [Apollo](https://genomearchitect.readthedocs.io/en/latest/)

## Pipeline Process

### Cleaning Raw Assembly

The old adage states that low quality input will surely result in low quality output, or more colloquially, "Garbage In, Garbage Out". Thus, before annotating a genome assembly it is good practice to remove potential "garbage" from the mix. To do so, contigs of uninformative length and those belonging to possible contaminants (it happens to the best of us...) should be removed. Because the method of contaminant removal used in this pipeline involves comparing <i>all</i> assembled contigs to <i>all</i> [nonredundant nucleotide sequences in NCBI](https://www.ncbi.nlm.nih.gov/books/NBK62345/#blast_ftp_site.The_blastdb_subdirectory), it is time efficeint to remove unhelpful contigs first, however, there is nothing inherently wrong with reversing the order.

#### <b>Size Selection</b>

Assembled contigs less than 1000bps can be removed as follows:

```bash
process_fasta_sequences.py \
	--fasta <assembly-name>.fasta \
	--min 1000 \
	--outdir $WORK_DIR
```

The 'process' in [<i>process_fasta_sequences.py</i>](https://github.com/PombertLab/A2A/blob/main/process_fasta_sequences.py) is not only size selection, but reordering contigs by length (largest to smallest), and providing unique/meaningful names. Additional options are available for fine-tuning:

```
-f (--fasta)	Input fasta file(s)
-o (--outdir)	Output directory [Default: processed_fastas]

-p (--prefix)	Prefix to give contigs [Default: contig_]
-n (--min)	Minimum contig length [Default: 500]
-x (--max)	Maximum contig length [Default: None]
```

#### <b>Identify and Remove Contaminants</b>

Now that extraneous contigs have been removed, the genetic origin of remaining contigs should be checked. To do so, a sequence homology search utilizing [NCBI's BLAST+](https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/) suite is performed:

```bash
runTaxonomizedBLAST.pl \
	-t 4 \
	-p blastn \
	-a megablast \
	-d nt \
	-q $WORK_DIR/<assembly-name>.fasta \
	-e 1e-10 \
	-c 1 \
	-o $WORK_DIR
```

Here, the sequence homology search is performed at the nucleotide level `(-p blastn)` against the non-redundant nucleotide database `(-d nt)`, with an error value cutoff of 1e-10 `(-e 1e-10)`, using 4 computing threads `(-t 4)`. Because the <b>best</b> genetic origin is desired, a culling limit of 1 `(-c 1)` has been specified.

The output of runTaxonomizedBLAST.pl will look something to the following:

```
## qseqid sseqid qstart qend pident length bitscore evalue staxids sscinames sskingdoms sblastnames
contig_01	gi|303303011|gb|CP001952.1|	4002	240259	99.986	236259	4.361e+05	0.0	876142	Encephalitozoon intestinalis ATCC 50506	Eukaryota	microsporidians
contig_02	gi|303302113|gb|CP001947.1|	7982	206197	99.997	198217	3.660e+05	0.0	876142	Encephalitozoon intestinalis ATCC 50506	Eukaryota	microsporidians
contig_03	gi|303301797|gb|CP001945.1|	6983	196774	99.995	189795	3.504e+05	0.0	876142	Encephalitozoon intestinalis ATCC 50506	Eukaryota	microsporidians
.
.
.
contig_38	gi|1909942514|dbj|AP023533.1|	10	1850	96.929	1856	3097	0.0	9606	Homo sapiens	Eukaryota	primates
```

The final three columns contain the taxon information for the <b>best</b> genetic origin of each contig, and contigs whose genetic origin does not match to specific scientific name(s) can be removed with:

```bash
parseTaxonomizedBLAST.pl 
	-b $WORK_DIR/*.blastn.6 \
	-f $WORK_DIR/<assembly-name>.fasta \
	-n "organism of interest 1" "organism of interest 2"
	-e 1e-10 \
	-o $WORK_DIR/<assembly-name>.parsed.fasta
```

Different naming conventions can be used to remove contaminants, and additional options are as follows:

```bash
-b | --blast		BLAST input file(s)
-f | --fasta		FASTA file(s)
-n | --name			Names to be queried
-i | --inverse		Returns queries NOT matching specified names
-c | --column		Which columns to query: sscinames, sskingdoms or sblastnames [Default: sscinames] 
-e | --evalue		Evalue cutoff for target organism(s) [Default: 1e-10]
-o | --output		FASTA output file containing the desired sequences
-k | --keep			Keep non-BLAST-match Sequences 
-v | --verbose		Verbose [Default: off]
```

### Orienting to a Reference Genome (Optional)

If a reference genome exists for the one being annotated, the contig-chromosome relationship may be desirable information to have. Keeping naming and orientation consistent between isolates, and even between close species, helps simplify future analysis. Utilizing a reference assembly, we can determine if the assembled contigs are in the _same_ or _reverse complement_ orientation compared to the reference, and reoreint them accordingly:

```bash
orient_fastas_to_reference.py \
	-f $WORK_DIR/<assembly-name>.parsed.fasta \
	-r <reference-assembly>.fasta \
	-o $WORK_DIR
```

Fine-tuning the parameters to assign orientation is possible with additional options:

```
-i (--min_pident)	Minimum percent identity to assign segment to reference [Default: 95%]
-a (--min_palign)	Minumum percent of the contig participating in alignment to assign segment to reference [Default: 5%]
-v (--max_overlp)	Maximum percent of alignment allowed to overlap a previous alignment to assign segment to reference [Default: 5%]
```

### Prepare Apollo for Annotations

For this part of the pipeline, access to an established [Apollo](https://genomearchitect.readthedocs.io/en/latest/) server in necessary. For information on how to setup an Apollo instance, refer to the Apollo [Setup Guide](https://genomearchitect.readthedocs.io/en/latest/Setup.html#:~:text=Download%20Apollo%20from%20the%20latest%20release%20under%20source-code,for%20production%20continue%20onto%20configuration%20below%20after%20install.). <b><i> NOTE: arrow-based operations must be performed on the server hosting the Apollo browser. </i> </b>


There are several steps to setting up the Apollo enviroment for the annotation process:
- create an organism and upload its genome data to Apollo
- create and load predicted genes to Apollo as annotations
- create and load evidence based annotations using sequence homology searches on references

This pipeline utilizes the [Apollo API](https://github.com/galaxy-genome-annotation/python-apollo), a handy python intermediate for communicating with the Apollo backend. 
Before moving through the following steps, be sure to initiallize the arrow CLI tool by running:
```bash
arrow init
```
You will be prompted to sign in so arrow can access your Apollo account. <b><i>BE AWARE, this will store your username and password in a plain text file in your home directory (~/.apollo-arrow.yml)!</i></b>


#### <b>Creating an Organism</b>

For the functionality of <i>[apollo_annator_utilities.py]()</i>, there needs to exist an enviromental path variable `$APOLLO` that points to the installation directory of the Apollo distribution.

```bash
export APOLLO=/path/to/Apollo
```

To add annotations to your organism, you will first need to create an instance of it on Apollo:

```bash
apollo_annotator_utilities.py \
  --add_organism \
	-f $WORK_DIR/<assembly-name>/<assembly-name>.oriented.fasta \
	-g "Genus of organism" \
	-s "Species of organism" \
	-i "User-defined ID of organism"
```


#### <b>Create and Load Prediction Data as Annotations</b>

There are a number of tools that can be used to predict gene models, such as [GeneMark](http://exon.gatech.edu/GeneMark/) and [Augustus](https://bioinf.uni-greifswald.de/augustus/). For our purposes, we utilize [Prodigal](https://github.com/hyattpd/Prodigal).

Predicting gene models with Prodigal is straight-forward:

```bash
prodigal \
	-i $WORK_DIR/<assembly-name>/<assembly-name>.oriented.fasta \
	-c \
	-a $WORK_DIR/<assembly>.faa
	-f gff \
	-o $WORK_DIR/<assembly-name>.gff
```

Apollo requires the mRNA/exon feature to add predictions as annotations, which is missing in the gff file produced by Prodigal. These featueres can be added to the Prodigal gff file with:

```bash
prodigal_to_apollo_gff.py \
	-g $WORK_DIR/<assembly-name>.gff
```

Not all gene predictions will be accurate, however, and smaller genes can be spurious. Separating genes by size, we can create annotations from the larger genes automatically, and add the smaller genes when evidence supports them, saving time. To parse the smaller genes from the larger ones, the following command can be used:

```bash
size_sort_gff.py \
	-g $WORK_DIR/<assembly-name>.apollo.gff \
	-a 60
	-o $SIZE_SORT_DIR
```

The gff file can then be uploaded as user-loaded annotations:

```bash
apollo_annotator_utilities.py \
  --load_annotations \
	-i "User-defined ID of organism" \
	-a $SIZE_SORT_DIR/proteins.long.gff
```

#### <b>Create and Load References</b>

Reference annotations can be used to assess the validity of protein predictions that were loaded as user annotations, in addition to identifying the presence of introns, untraslated transcription regions (UTRs) and/or broken reading frames. This can be done by performing a sequence homology search of validated proteins against the assembled genome.

The sequence homology search is performated between the the selected reference(s) and the assembled genome as follows:

```bash
tblastn \
	-query <reference-protein>.faa \
	-subject $WORK_DIR/<assembly-name>/<assembly-name>.oriented.fasta \
	-culling_limit 1 \
	-evalue 1e-05 \
	-outfmt 6 \
	-out $WORK_DIR/BLAST/<reference-name>.tblastn.6
```

Because Apollo accepts gff files, the sequence homology results need to be converted:

```bash
blast_to_apollo_gff.py \
	-b $WORK_DIR/BLAST/<reference-name>.tblastn.6 \
	-a <reference-protein>.products
```

Then the reference gff can be added to Apollo for comparison purposeses, with the following command:

```bash
apollo_annotator_utilities.py \
  --add_reference \
	-i "User-defined ID of organism" \
	-r $WORK_DIR/BLAST/<reference-name>.tblastn.6 \
	-t match,match_part \
	-l <track-label>
```

This step can be repeated for as many references, tRNAs, rRNAs, and others, that Apollo will accept.

## Literature

Altschul SF, Gish W, Miller W, Myers EW, Lipman DJ. **Basic local alignment search tool.** *J Mol Biol.* 1990 Oct 5;215(3):403-10. doi: [10.1016/S0022-2836(05)80360-2](https://doi.org/10.1016/s0022-2836(05)80360-2). PMID: 2231712.

Hyatt, D., Chen, GL., LoCascio, P.F. et al. **Prodigal: prokaryotic gene recognition and translation initiation site identification.** BMC Bioinformatics 11, 119 (2010). doi: [10.1186/1471-2105-11-119](https://doi.org/10.1186/1471-2105-11-119)

Barrett T, Clark K, Gevorgyan R, Gorelenkov V, Gribov E, Karsch-Mizrachi I, Kimelman M, Pruitt KD, Resenchuk S, Tatusova T, Yaschenko E, Ostell J. **BioProject and BioSample databases at NCBI: facilitating capture and organization of metadata.** 
*Nucleic Acids Res.* 2012 Jan;40(Database issue):D57-63. doi: [10.1093/nar/gkr1163](https://doi.org/10.1093/nar/gkr1163). Epub 2011 Dec 1. PMID: 22139929; PMCID: PMC3245069.

Dunn NA, Unni DR, Diesh C, Munoz-Torres M, Harris NL, Yao E, Rasche H, Holmes IH, Elsik CG, Lewis SE. **Apollo: Democratizing genome annotation.** *PLoS Comput Biol.* 2019 Feb 6;15(2):e1006790. doi: [10.1371/journal.pcbi.1006790](https://doi.org/10.1371/journal.pcbi.1006790). PMID: 30726205; PMCID: PMC6380598.

Brůna T, Lomsadze A, Borodovsky M. **GeneMark-EP+: eukaryotic gene prediction with self-training in the space of genes and proteins.** *NAR Genom Bioinform.* 2020 Jun;2(2):lqaa026. [doi: 10.1093/nargab/lqaa026](https://doi.org/10.1093/nargab/lqaa026) PMID: 32440658; PMCID: PMC7222226.

Mario Stanke, Mark Diekhans, Robert Baertsch, David Haussler **Using native and syntenically mapped cDNA alignments to improve de novo gene finding.** *Bioinformatics* 2008 24(5), pages 637–644, [doi: 10.1093/bioinformatics/btn013](https://doi.org/10.1093/bioinformatics/btn013)
