nextflow.enable.dsl=2

//Define message for the process logs.
log.info """\
         R N A S E Q - F U S I O N  P I P E L I N E
         ===================================
         star_refs      :   ${params.star_genome_lib}
         cicero_refs    :   ${params.cicero_genome_lib}
         samples        :   ${params.sample_sheet}
         """
         .stripIndent()


include {
        unzip as gunzip_fasta
        unzip as gunzip_gtf } from './modules/local/fusion-processes.nf'
include {
        MD5sums as md5_star
        MD5sums as md5_cicero } from './modules/local/fusion-processes.nf'
include { SAMTOOLS_INDEX } from './modules/nf-core/samtools/index/main'
include { 
        STAR_Prep_Fusion;
        STAR_Fusion; 
        fastqc; 
        multiqc; 
        STAR_index; 
        STAR_aligner; 
        CICERO } from './modules/local/fusion-processes.nf'

// Function which prints help message text
def helpMessage() {
    log.info"""
Usage:
nextflow run jennylsmith/STAR-fusion-NF <ARGUMENTS>
Required Arguments:
  Input Data:
  --sample_sheet        Single file with the location of all input data. Must be formatted
                        as a CSV with columns: Sample,R1,R2
  Reference Data:
  --star_genome_lib     The location of the CTAT Resource Library for STAR-Fusion - See https://data.broadinstitute.org/Trinity/CTAT_RESOURCE_LIB/ for available ones
  --cicero_genome_lib   The location of the References for CICERO Fusion - See https://github.com/stjude/CICERO#reference for available references.
  
  Optional Arguments:
  --fasta_file          Location of directory which contains the reference genome fasta file (single file) for the optional STAR fusion index step
  --gtf_url             URL of the gtf file for the optional STAR index step - for example on gencode FTP "ftp.ebi.ac.uk/pub/databases/gencode/"
  
  Output Locations:
  --STAR_Fusion_out
  --multiQC_out
  --star_index_out
  --STAR_aligner_out
 """.stripIndent()
}

//Workflow to create an index for STAR-aligner given a human genome fasta and the location of the GTF file. 
workflow star_index {
    //Download and stage the GTF file 
    Channel.fromPath(file(params.gtf, checkIfExists: true))
        .set{ gtf }
     //if gtf is gzipped, it must be decompressed   
    if(params.gtf.endsWith(".gz")){
        gunzip_gtf(gtf)
        gunzip_gtf.out.unzipped_file
            .set{ gtf }
    } 
    //Stage the genome fasta files for the index building step
    Channel.fromPath(file(params.fasta_file, checkIfExists: true))
        .set{ fasta }
    // if fasta  is gzipped, it must be decompressed   
    if(params.fasta_file.endsWith(".gz")){
        gunzip_fasta(fasta)
        gunzip_fasta.out.unzipped_file.set{fasta}
    }
    //Call STAR genomeGenerate to build the index
    STAR_index(fasta, gtf)
}

workflow  fusion_calls {
    // Define the input paired fastq files in a sample sheet and genome references.
    //The sample_sheet is comma separated with column names "Sample","R1","R2"
    Channel.fromPath(file(params.sample_sheet))
        .splitCsv(header: true, sep: ',')
        .map { sample -> [ sample["Sample"] + "_", 
                           file(sample["R1"], checkIfExists: true), 
                           file(sample["R2"], checkIfExists: true) ]
            }
        .set { fqs_ch }

    //run QC on the fastq files
    fastqc(fqs_ch)
    sample_sheet=file(params.sample_sheet)
    multiqc(fastqc.out.collect(), sample_sheet.simpleName)

    //processes are treated like functions
    Channel.fromPath(file(params.star_genome_lib, checkIfExists: true))
        .collect()
        .set { star_genome_lib }
    STAR_Prep_Fusion(star_genome_lib, fqs_ch)
    STAR_Fusion(star_genome_lib, fqs_ch, STAR_Prep_Fusion.out.chimera)
    md5_star(STAR_Prep_Fusion.out.bam)

    //CICERO requires GRCh37-lite aligned BAMs, so dependent on STAR-aligner BAM 
    Channel.fromPath(file(params.star_index_out, checkIfExists: true))
        .collect()
        .set { star_index }
    STAR_aligner(star_index, fqs_ch)
    SAMTOOLS_INDEX(STAR_aligner.out.bam)
    md5_cicero(STAR_aligner.out.bam)
    STAR_aligner.out.bam
        .join(SAMTOOLS_INDEX.out.bai)
        .set { bam_bai_ch }

    //Run CICERO on the STAR-aligner BAM files.
    Channel.fromPath(file(params.cicero_genome_lib, checkIfExists: true))
        .collect()
        .set { cicero_genome_lib }
    CICERO(cicero_genome_lib, bam_bai_ch)
}