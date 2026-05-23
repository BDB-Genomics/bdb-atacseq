#!/usr/bin/env python3
"""Generate minimal test data for CI pipeline validation."""

import gzip
import os
import random
import struct

random.seed(42)

CHROMOSOMES = ["chr1", "chr2", "chr3", "chrMT"]
CHROM_SIZES = {"chr1": 248956422, "chr2": 242193529, "chr3": 198295559, "chrMT": 16569}

def generate_fastq(filename, n_reads=1000, read_len=75):
    """Generate a minimal FASTQ file with random sequences."""
    bases = "ACGT"
    qualities = "IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII"
    with gzip.open(filename, "wt") as f:
        for i in range(n_reads):
            seq = "".join(random.choice(bases) for _ in range(read_len))
            header = f"@READ{i:06d}/1"
            f.write(f"{header}\n{seq}\n+\n{qualities[:read_len]}\n")

def generate_genome(filename, n_bases=500000):
    """Generate a minimal reference genome."""
    bases = "ACGT"
    with open(filename, "w") as f:
        f.write(">chr1\n")
        seq = "".join(random.choice(bases) for _ in range(n_bases))
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")
        f.write(">chr2\n")
        seq = "".join(random.choice(bases) for _ in range(n_bases // 2))
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")
        f.write(">chrMT\n")
        seq = "".join(random.choice(bases) for _ in range(16569))
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")

def generate_chrom_sizes(filename):
    """Generate chromosome sizes file."""
    with open(filename, "w") as f:
        f.write("chr1\t500000\n")
        f.write("chr2\t250000\n")
        f.write("chrMT\t16569\n")

def generate_blacklist(filename):
    """Generate a minimal blacklist file."""
    with open(filename, "w") as f:
        f.write("chr1\t100000\t101000\n")
        f.write("chr2\t50000\t51000\n")

def generate_annotation(filename):
    """Generate a minimal GTF annotation file."""
    with open(filename, "w") as f:
        f.write('chr1\ttest\tgene\t50000\t55000\t.\t+\t.\tgene_id "GENE1"; gene_name "TEST1";\n')
        f.write('chr1\ttest\texon\t50000\t51000\t.\t+\t.\tgene_id "GENE1"; transcript_id "TX1";\n')
        f.write('chr1\ttest\texon\t53000\t55000\t.\t+\t.\tgene_id "GENE1"; transcript_id "TX1";\n')
        f.write('chr2\ttest\tgene\t100000\t105000\t.\t-\t.\tgene_id "GENE2"; gene_name "TEST2";\n')
        f.write('chr2\ttest\texon\t100000\t102000\t.\t-\t.\tgene_id "GENE2"; transcript_id "TX2";\n')

def generate_motif_db(filename):
    """Generate a minimal MEME motif database."""
    with open(filename, "w") as f:
        f.write("MEME version 5\n\n")
        f.write("ALPHABET= ACGT\n\n")
        f.write("strands: + -\n\n")
        f.write("Background letter frequencies\n")
        f.write("A 0.25 C 0.25 G 0.25 T 0.25\n\n")
        f.write("MOTIF TEST_MOTIF_1\n")
        f.write("letter-probability matrix: alength= 4 w= 8 nsites= 20 E= 1e-5\n")
        for _ in range(8):
            f.write("0.25 0.25 0.25 0.25\n")
        f.write("\n")

def generate_bt2_index(directory):
    """Generate minimal Bowtie2 index files (binary placeholders)."""
    os.makedirs(directory, exist_ok=True)
    for ext in ["1.bt2", "2.bt2", "3.bt2", "4.bt2", "rev.1.bt2", "rev.2.bt2"]:
        path = os.path.join(directory, f"genome.{ext}")
        with open(path, "wb") as f:
            f.write(struct.pack("<I", 500000))
            f.write(b"\x00" * 1000)

def generate_samples_tsv(filename):
    """Generate a minimal sample sheet."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w") as f:
        f.write("sample\tfastq_r1\tfastq_r2\treplicate\tcondition\n")
        f.write("sample1\tdata/fastq/sample1_R1.fastq.gz\tdata/fastq/sample1_R2.fastq.gz\t1\tcontrol\n")
        f.write("sample2\tdata/fastq/sample2_R1.fastq.gz\tdata/fastq/sample2_R2.fastq.gz\t2\tcontrol\n")
        f.write("sample3\tdata/fastq/sample3_R1.fastq.gz\tdata/fastq/sample3_R2.fastq.gz\t1\ttreated\n")

def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    print("Generating test data...")

    os.makedirs(f"{root}/data/fastq", exist_ok=True)
    os.makedirs(f"{root}/data/reference/index", exist_ok=True)
    os.makedirs(f"{root}/data/motifs", exist_ok=True)

    for sample in ["sample1", "sample2", "sample3"]:
        generate_fastq(f"{root}/data/fastq/{sample}_R1.fastq.gz", n_reads=500)
        generate_fastq(f"{root}/data/fastq/{sample}_R2.fastq.gz", n_reads=500)

    # Generate mock CI FASTQ files in root
    generate_fastq(f"{root}/ci_r1.fq.gz", n_reads=500)
    generate_fastq(f"{root}/ci_r2.fq.gz", n_reads=500)

    generate_genome(f"{root}/data/reference/genome.fa")
    generate_chrom_sizes(f"{root}/data/reference/genome.chrom.sizes")
    generate_blacklist(f"{root}/data/reference/ENCODE_blacklist.bed")
    generate_annotation(f"{root}/data/reference/annotation.gtf")
    generate_motif_db(f"{root}/data/motifs/jaspar_vertebrates.meme")
    generate_bt2_index(f"{root}/data/reference/index")
    generate_samples_tsv(f"{root}/data/fastp/samples.tsv")

    # Generate mock chromap index
    os.makedirs(f"{root}/data/reference/chromap", exist_ok=True)
    with open(f"{root}/data/reference/chromap/genome.index", "w") as f:
        f.write("placeholder")

    print("Test data generated successfully.")
    print(f"  Genome: {root}/data/reference/genome.fa")
    print(f"  Samples: {root}/data/fastp/samples.tsv")
    print(f"  FASTQ: {root}/data/fastq/")

if __name__ == "__main__":
    main()
