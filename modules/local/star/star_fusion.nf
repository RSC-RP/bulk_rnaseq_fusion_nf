process STAR_FUSION {
    // use TrinityCTAT image repo on Quay.io from Biocontainers
    container "quay.io/biocontainers/star-fusion:1.12.0--hdfd78af_1"
    // container "https://data.broadinstitute.org/Trinity/CTAT_SINGULARITY/STAR-Fusion/star-fusion.v1.12.0.simg"

    // declare the input types and its variable names
    input:
    tuple val(sample), path(R1), path(R2), path(chimeric_juncs)
    path genome_lib

    //define output files to save to the output_folder by publishDir command
    output:
    path("${sample}/*abridged.tsv")                                 , emit: fusions
    path("${sample}/*coding_effect.tsv")                            , emit: coding_effect, optional: true
    path("${sample}/*fusion_evidence_reads_*.fq")                   , emit: fastqs, optional: true
    path("${sample}/FusionInspector.log")                           , emit: log, optional: true
    path("${sample}/FusionInspector-{inspect,validate}/*.*")        , emit: inspector, optional: true

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample}"
    """
    set -eou pipefail

    STAR-Fusion \\
        --genome_lib_dir \$PWD/$genome_lib \\
        --chimeric_junction ${chimeric_juncs} \\
        --left_fq $R1 \\
        --right_fq $R2 \\
        --CPU ${task.cpus} \\
        --output_dir ${sample} \\
        $args \\
        --tmpdir \$PWD \\
        --outTmpDir \$PWD 
    """
}
