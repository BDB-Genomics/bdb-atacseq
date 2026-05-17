#!/usr/bin/env bash
set -euo pipefail

# Define workspace directories
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="${ROOT}/data"
FASTQ_DIR="${DATA_DIR}/fastq"
REF_DIR="${DATA_DIR}/reference"
INDEX_DIR="${REF_DIR}/index"
MOTIFS_DIR="${DATA_DIR}/motifs"
TMP_DIR="${DATA_DIR}/tmp_download"

echo "=== Creating Directories ==="
mkdir -p "${FASTQ_DIR}"
mkdir -p "${INDEX_DIR}"
mkdir -p "${MOTIFS_DIR}"
mkdir -p "${TMP_DIR}"

cd "${TMP_DIR}"

echo "=== Downloading FASTQ Files (subsampled ENCSR356KRQ) ==="
# Sample 1 (Control Rep 1)
wget -O "${FASTQ_DIR}/sample1_R1.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep1/pair1/ENCFF341MYG.subsampled.400.fastq.gz"
wget -O "${FASTQ_DIR}/sample1_R2.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep1/pair2/ENCFF248EJF.subsampled.400.fastq.gz"

# Sample 2 (Control Rep 2)
wget -O "${FASTQ_DIR}/sample2_R1.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep1/pair1/ENCFF106QGY.subsampled.400.fastq.gz"
wget -O "${FASTQ_DIR}/sample2_R2.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep1/pair2/ENCFF368TYI.subsampled.400.fastq.gz"

# Sample 3 (Treated Rep 1)
wget -O "${FASTQ_DIR}/sample3_R1.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep2/pair1/ENCFF641SFZ.subsampled.400.fastq.gz"
wget -O "${FASTQ_DIR}/sample3_R2.fastq.gz" "https://storage.googleapis.com/encode-pipeline-test-samples/encode-atac-seq-pipeline/ENCSR356KRQ/fastq_subsampled/rep2/pair2/ENCFF031ARQ.subsampled.400.fastq.gz"

echo "=== Downloading Genome Sequences (UCSC hg38 chr19 & chrM) ==="
wget -O "chr19.fa.gz" "https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr19.fa.gz"
wget -O "chrM.fa.gz" "https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chrM.fa.gz"

echo "=== Downloading Annotation (GENCODE v44 basic) ==="
wget -O "gencode.v44.basic.annotation.gtf.gz" "https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_44/gencode.v44.basic.annotation.gtf.gz"

echo "=== Downloading ENCODE Blacklist BED ==="
wget -O "ENCFF356LFX.bed.gz" "https://www.encodeproject.org/files/ENCFF356LFX/@@download/ENCFF356LFX.bed.gz"

echo "=== Downloading JASPAR Vertebrates Meme Database ==="
wget -O "${MOTIFS_DIR}/jaspar_vertebrates.meme" "https://jaspar.elixir.no/download/data/2024/CORE/JASPAR2024_CORE_vertebrates_non-redundant_pfms_meme.txt"

echo "=== Post-processing Genome and Reference Files ==="
# 1. Combine FASTA files
zcat chr19.fa.gz chrM.fa.gz > "${REF_DIR}/genome.fa"

# 2. Extract chr19 and chrM from GENCODE GTF
zcat gencode.v44.basic.annotation.gtf.gz | grep -E "^(chr19|chrM)[[:space:]]" > "${REF_DIR}/annotation.gtf"

# 3. Extract chr19 and chrM from ENCODE Blacklist
zcat ENCFF356LFX.bed.gz | grep -E "^(chr19|chrM)[[:space:]]" > "${REF_DIR}/ENCODE_blacklist.bed"

# 4. Create chrom.sizes
echo -e "chr19\t58617616\nchrM\t16569" > "${REF_DIR}/genome.chrom.sizes"

echo "=== Building Bowtie2 Index ==="
BOWTIE2_BUILD=$(which bowtie2-build 2>/dev/null || find /home/himanshu/miniconda3 -name "bowtie2-build" -print -quit 2>/dev/null || find /home/mangala/miniconda3 -name "bowtie2-build" -print -quit 2>/dev/null || echo "bowtie2-build")
"${BOWTIE2_BUILD}" "${REF_DIR}/genome.fa" "${INDEX_DIR}/genome"

echo "=== Cleaning Up Temporary Files ==="
rm -rf "${TMP_DIR}"

echo "=== Setup Completed Successfully! ==="
echo "Genome Reference: ${REF_DIR}/genome.fa"
echo "Chromosome Sizes: ${REF_DIR}/genome.chrom.sizes"
echo "Blacklist BED: ${REF_DIR}/ENCODE_blacklist.bed"
echo "Annotation GTF: ${REF_DIR}/annotation.gtf"
echo "JASPAR MEME DB: ${MOTIFS_DIR}/jaspar_vertebrates.meme"
echo "Bowtie2 Index: ${INDEX_DIR}/"
ls -lh "${FASTQ_DIR}"
