#!/usr/bin/env python3
"""Generate synthetic test data for CI pipeline validation.

This script produces a minimal but sufficient synthetic dataset so that
every rule in the ATAC-seq pipeline — including tss_enrichment.R's
featureAlignedSignal() call — exits cleanly in CI.

Key sizing decisions (derived from tss_enrichment.R requirements):
  • featureAlignedSignal() tiles each TSS ±2000 bp (4 kb window) into
    200 bins (20 bp/bin).  It needs non-zero coverage across those bins
    for multiple TSS regions, otherwise the names/length mismatch crash
    occurs.
  • We therefore generate ≥50 genes spread across chr1 and chr2, and
    target ~60 % of reads to land within 2 kb of a TSS.  This guarantees
    dense coverage inside the tiling windows.
"""

import gzip
import os
import random
import struct
import subprocess
from typing import Dict, List

random.seed(42)

# ---------------------------------------------------------------------------
# Genome layout
# ---------------------------------------------------------------------------
GENOME = {
    "chr1":  500_000,
    "chr2":  250_000,
    "chrMT":  16_569,
}

# ---------------------------------------------------------------------------
# Annotation parameters
# ---------------------------------------------------------------------------
GENES_CHR1 = 50          # genes on chr1
GENES_CHR2 = 30          # genes on chr2
GENE_LENGTH = 3000        # bp per gene body
GENE_SPACING_CHR1 = 12_000
GENE_SPACING_CHR2 = 10_000
GENE_START_OFFSET = 10_000  # first gene starts here

# ---------------------------------------------------------------------------
# FASTQ parameters
# ---------------------------------------------------------------------------
READS_PER_SAMPLE = 20000
READ_LENGTH = 75
FRAGMENT_MEAN = 200
FRAGMENT_SD = 30
TSS_TARGETED_FRACTION = 0.75   # fraction of reads placed near TSSes
TSS_WINDOW = 2000              # how far from TSS we scatter targeted reads
SAMPLES = ["sample1", "sample2", "sample3", "sample4"]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def reverse_complement(seq: str) -> str:
    """Return the reverse complement of a DNA sequence."""
    table = str.maketrans("ACGTNacgtn", "TGCANtgcan")
    return seq.translate(table)[::-1]


def random_seq(length: int) -> str:
    """Generate a random DNA sequence of the given length."""
    return "".join(random.choice("ACGT") for _ in range(length))


# ---------------------------------------------------------------------------
# Genome generation
# ---------------------------------------------------------------------------

def generate_genome(filepath: str) -> Dict[str, str]:
    """Write a FASTA genome and return {chrom: sequence}."""
    sequences = {}
    offset = 0
    with open(filepath, "w") as fh, open(filepath + ".fai", "w") as fai:
        for chrom, size in GENOME.items():
            seq = random_seq(size)
            sequences[chrom] = seq
            header = f">{chrom}\n"
            fh.write(header)
            offset += len(header)
            
            fai.write(f"{chrom}\t{size}\t{offset}\t80\t81\n")
            
            for i in range(0, len(seq), 80):
                chunk = seq[i : i + 80] + "\n"
                fh.write(chunk)
                offset += len(chunk)
    return sequences


def generate_chrom_sizes(filepath: str) -> None:
    """Write a chrom.sizes file matching the genome."""
    with open(filepath, "w") as fh:
        for chrom, size in GENOME.items():
            fh.write(f"{chrom}\t{size}\n")


# ---------------------------------------------------------------------------
# Annotation generation
# ---------------------------------------------------------------------------

def _make_genes(chrom: str, n_genes: int, spacing: int, chrom_size: int) -> List[dict]:
    """Return a list of gene dicts for one chromosome."""
    genes = []
    for i in range(n_genes):
        start = GENE_START_OFFSET + i * spacing
        end = start + GENE_LENGTH
        if end >= chrom_size - 1000:
            break
        strand = "+" if i % 2 == 0 else "-"
        gene_id = f"{chrom.upper()}_GENE{i + 1:03d}"
        genes.append(dict(
            chrom=chrom, start=start, end=end,
            strand=strand, gene_id=gene_id,
        ))
    return genes


def generate_annotation(filepath: str) -> List[dict]:
    """Write a GTF annotation and return the list of gene records."""
    all_genes: List[dict] = []
    all_genes += _make_genes("chr1", GENES_CHR1, GENE_SPACING_CHR1, GENOME["chr1"])
    all_genes += _make_genes("chr2", GENES_CHR2, GENE_SPACING_CHR2, GENOME["chr2"])

    with open(filepath, "w") as fh:
        for g in all_genes:
            c, s, e, st, gid = g["chrom"], g["start"], g["end"], g["strand"], g["gene_id"]
            tx_id = f"TX_{gid}"
            # gene line
            fh.write(f'{c}\ttest\tgene\t{s}\t{e}\t.\t{st}\t.\t'
                     f'gene_id "{gid}"; gene_name "{gid}";\n')
            # transcript line
            fh.write(f'{c}\ttest\ttranscript\t{s}\t{e}\t.\t{st}\t.\t'
                     f'gene_id "{gid}"; transcript_id "{tx_id}";\n')
            # exon 1 (first 1000 bp)
            fh.write(f'{c}\ttest\texon\t{s}\t{s + 1000}\t.\t{st}\t.\t'
                     f'gene_id "{gid}"; transcript_id "{tx_id}";\n')
            # exon 2 (last 1000 bp)
            fh.write(f'{c}\ttest\texon\t{e - 1000}\t{e}\t.\t{st}\t.\t'
                     f'gene_id "{gid}"; transcript_id "{tx_id}";\n')
    return all_genes


# ---------------------------------------------------------------------------
# FASTQ generation
# ---------------------------------------------------------------------------

def _tss_position(gene: dict) -> int:
    """Return the TSS coordinate for a gene."""
    return gene["start"] if gene["strand"] == "+" else gene["end"]


def generate_fastq_paired(
    r1_path: str,
    r2_path: str,
    genome_seqs: Dict[str, str],
    genes: List[dict],
    n_reads: int = READS_PER_SAMPLE,
) -> None:
    """Generate paired-end FASTQ with reads enriched near TSSes."""
    # Degrade quality at the ends of the reads so FastQC actually flags them
    quals = "I" * (READ_LENGTH - 15) + "5" * 15
    n_targeted = int(n_reads * TSS_TARGETED_FRACTION)
    n_random = n_reads - n_targeted

    # Pre-compute TSS positions grouped by chromosome
    tss_by_chrom: Dict[str, List[int]] = {}
    for g in genes:
        tss_by_chrom.setdefault(g["chrom"], []).append(_tss_position(g))

    # Chromosomes that have genes (for targeted reads)
    gene_chroms = [c for c in tss_by_chrom if c in genome_seqs]

    with gzip.open(r1_path, "wt") as f1, gzip.open(r2_path, "wt") as f2:
        read_idx = 0

        # --- Targeted reads: placed within TSS_WINDOW of a TSS -----------
        for _ in range(n_targeted):
            chrom = random.choice(gene_chroms)
            seq = genome_seqs[chrom]
            tss = random.choice(tss_by_chrom[chrom])

            # Pick a random position within ±TSS_WINDOW of the TSS
            frag_len = max(
                READ_LENGTH + 10,
                min(int(random.gauss(FRAGMENT_MEAN, FRAGMENT_SD)), 400),
            )
            offset = random.randint(-TSS_WINDOW, TSS_WINDOW)
            pos = tss + offset
            pos = max(0, min(pos, len(seq) - frag_len))

            fragment = seq[pos : pos + frag_len]
            r1_seq = fragment[:READ_LENGTH]
            r2_seq = reverse_complement(fragment[-READ_LENGTH:])

            f1.write(f"@READ{read_idx:06d}/1\n{r1_seq}\n+\n{quals}\n")
            f2.write(f"@READ{read_idx:06d}/2\n{r2_seq}\n+\n{quals}\n")
            read_idx += 1

        # --- Ultra-dense Spike-in for Peak Calling -----------
        # We'll put reads in 15 regions on chr1.
        chrom = "chr1"
        if chrom in genome_seqs and chrom in tss_by_chrom:
            seq = genome_seqs[chrom]
            num_peaks = min(15, len(tss_by_chrom[chrom]))
            reads_per_peak = max(1, 1000 // num_peaks)
            for i in range(num_peaks):
                tss = tss_by_chrom[chrom][i]
                for _ in range(reads_per_peak):
                    frag_len = max(READ_LENGTH + 10, min(int(random.gauss(FRAGMENT_MEAN, FRAGMENT_SD)), 400))
                    offset = random.randint(-50, 50)
                    pos = tss + offset
                    pos = max(0, min(pos, len(seq) - frag_len))
    
                    fragment = seq[pos : pos + frag_len]
                    r1_seq = fragment[:READ_LENGTH]
                    r2_seq = reverse_complement(fragment[-READ_LENGTH:])
    
                    f1.write(f"@READ{read_idx:06d}/1\n{r1_seq}\n+\n{quals}\n")
                    f2.write(f"@READ{read_idx:06d}/2\n{r2_seq}\n+\n{quals}\n")
                    read_idx += 1

        # --- Random reads: uniformly distributed across the genome --------
        chrom_list = list(genome_seqs.keys())
        for _ in range(n_random):
            chrom = random.choice(chrom_list)
            seq = genome_seqs[chrom]
            frag_len = max(
                READ_LENGTH + 10,
                min(int(random.gauss(FRAGMENT_MEAN, FRAGMENT_SD)), 400),
            )
            if len(seq) <= frag_len:
                continue
            pos = random.randint(0, len(seq) - frag_len)

            fragment = seq[pos : pos + frag_len]
            r1_seq = fragment[:READ_LENGTH]
            r2_seq = reverse_complement(fragment[-READ_LENGTH:])

            f1.write(f"@READ{read_idx:06d}/1\n{r1_seq}\n+\n{quals}\n")
            f2.write(f"@READ{read_idx:06d}/2\n{r2_seq}\n+\n{quals}\n")
            read_idx += 1


# ---------------------------------------------------------------------------
# Supporting files
# ---------------------------------------------------------------------------

def generate_blacklist(filepath: str) -> None:
    """Write a minimal ENCODE-style blacklist BED."""
    with open(filepath, "w") as fh:
        fh.write("chr1\t100000\t101000\n")
        fh.write("chr2\t50000\t51000\n")


def generate_motif_db(filepath: str) -> None:
    """Write a minimal MEME motif database."""
    with open(filepath, "w") as fh:
        fh.write("MEME version 5\n\n")
        fh.write("ALPHABET= ACGT\n\n")
        fh.write("strands: + -\n\n")
        fh.write("Background letter frequencies\n")
        fh.write("A 0.25 C 0.25 G 0.25 T 0.25\n\n")
        fh.write("MOTIF TEST_MOTIF_1\n")
        fh.write("letter-probability matrix: alength= 4 w= 8 nsites= 20 E= 1e-5\n")
        for _ in range(8):
            fh.write("0.25 0.25 0.25 0.25\n")
        fh.write("\n")


def generate_bt2_index(index_dir: str, genome_fa: str) -> None:
    """Build a real Bowtie2 index, falling back to placeholders."""
    os.makedirs(index_dir, exist_ok=True)
    try:
        subprocess.run(
            ["bowtie2-build", genome_fa, os.path.join(index_dir, "genome")],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print("  Bowtie2 index built successfully.")
    except Exception:
        print("  Warning: bowtie2-build not found, writing placeholder index files.")
        for ext in ["1.bt2", "2.bt2", "3.bt2", "4.bt2", "rev.1.bt2", "rev.2.bt2"]:
            path = os.path.join(index_dir, f"genome.{ext}")
            with open(path, "wb") as fh:
                fh.write(struct.pack("<I", 500_000))
                fh.write(b"\x00" * 1000)


def generate_samples_tsv(filepath: str) -> None:
    """Write the sample sheet expected by the pipeline."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as fh:
        fh.write("sample\tfastq_r1\tfastq_r2\treplicate\tcondition\n")
        fh.write("sample1\tdata/fastq/sample1_R1.fastq.gz\tdata/fastq/sample1_R2.fastq.gz\t1\tcontrol\n")
        fh.write("sample2\tdata/fastq/sample2_R1.fastq.gz\tdata/fastq/sample2_R2.fastq.gz\t2\tcontrol\n")
        fh.write("sample3\tdata/fastq/sample3_R1.fastq.gz\tdata/fastq/sample3_R2.fastq.gz\t1\ttreated\n")
        fh.write("sample4\tdata/fastq/sample4_R1.fastq.gz\tdata/fastq/sample4_R2.fastq.gz\t2\ttreated\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    print("=" * 60)
    print("Generating synthetic CI test data")
    print("=" * 60)

    # Create directory tree
    for subdir in ["data/fastq", "data/reference/index", "data/motifs",
                    "data/reference/chromap"]:
        os.makedirs(os.path.join(root, subdir), exist_ok=True)

    # --- Reference genome ---------------------------------------------------
    genome_fa = os.path.join(root, "data/reference/genome.fa")
    print("\n[1/7] Reference genome ...")
    genome_seqs = generate_genome(genome_fa)
    for chrom, seq in genome_seqs.items():
        print(f"  {chrom}: {len(seq):,} bp")

    # --- Chromosome sizes ---------------------------------------------------
    print("[2/7] Chromosome sizes ...")
    generate_chrom_sizes(os.path.join(root, "data/reference/genome.chrom.sizes"))

    # --- Annotation GTF -----------------------------------------------------
    print("[3/7] Gene annotation ...")
    genes = generate_annotation(os.path.join(root, "data/reference/annotation.gtf"))
    print(f"  {len(genes)} genes ({sum(1 for g in genes if g['chrom'] == 'chr1')} chr1, "
          f"{sum(1 for g in genes if g['chrom'] == 'chr2')} chr2)")

    # --- Blacklist, motifs --------------------------------------------------
    print("[4/7] Blacklist + motif database ...")
    generate_blacklist(os.path.join(root, "data/reference/ENCODE_blacklist.bed"))
    generate_motif_db(os.path.join(root, "data/motifs/jaspar_vertebrates.meme"))

    # --- Bowtie2 index ------------------------------------------------------
    print("[5/7] Bowtie2 index ...")
    generate_bt2_index(os.path.join(root, "data/reference/index"), genome_fa)

    # --- Paired-end FASTQs --------------------------------------------------
    print(f"[6/7] Paired-end FASTQs ({READS_PER_SAMPLE} reads/sample, "
          f"{int(TSS_TARGETED_FRACTION * 100)}% TSS-targeted) ...")
    for sample in SAMPLES:
        generate_fastq_paired(
            os.path.join(root, f"data/fastq/{sample}_R1.fastq.gz"),
            os.path.join(root, f"data/fastq/{sample}_R2.fastq.gz"),
            genome_seqs,
            genes,
        )
        print(f"  {sample} ✓")



    # --- Misc placeholders --------------------------------------------------
    print("[7/7] Chromap index placeholder ...")
    with open(os.path.join(root, "data/reference/chromap/genome.index"), "w") as fh:
        fh.write("placeholder")

    # --- Sample sheet -------------------------------------------------------
    generate_samples_tsv(os.path.join(root, "data/samples.tsv"))

    # --- Summary ------------------------------------------------------------
    print("\n" + "=" * 60)
    print("Test data generated successfully.")
    print(f"  Genome  : {genome_fa}")
    print(f"  Genes   : {len(genes)}")
    print(f"  Samples : {len(SAMPLES)} × {READS_PER_SAMPLE} reads")
    print(f"  TSS-targeted fraction : {TSS_TARGETED_FRACTION:.0%}")
    print("=" * 60)


if __name__ == "__main__":
    main()
