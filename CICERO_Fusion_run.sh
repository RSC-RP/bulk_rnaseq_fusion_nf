#!/bin/bash
set -e
BASE_BUCKET="s3://fh-pi-meshinchi-s/SR"


# Load the module
# ml nextflow/19.11.0-edge
ml nextflow/20.04.0-edge


#Execute the next flow workflow  $BASE_BUCKET/work
nextflow run -c ~/nextflow.config STAR_Fusion.nf \
    --sample_sheet sample_sheets/DS.AML_sample_sheet.txt \
    --genome_lib $BASE_BUCKET/starfusion/GRCh37_gencode_v19_CTAT_lib_Oct012019/ctat_genome_lib_build_dir \
    --output_folder  $BASE_BUCKET/starfusion/DS_AML \
    -with-report STAR-Fusion_DS.AML_report.html \
    -work-dir $BASE_BUCKET/work \
    -cache  TRUE \
    -resume