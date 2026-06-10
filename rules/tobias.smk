import os

rule tobias_atacorrect:
    input:
        bam=lambda wildcards: f"{config['tobias']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        genome=config['tobias']['params']['genome_fa'],
        blacklist=config['tobias']['params']['blacklist']

    output:
        corrected_bw=f"{config['tobias']['output']['corrected_bw']}/{{sample}}_corrected.bw",
        bias_track=f"{config['tobias']['output']['bias_track']}/{{sample}}_bias.bw",
        log_file=f"{config['tobias']['output']['logs']}/{{sample}}_atacorrect.log"

    params:
        genome_sizes=config['tobias']['params']['genome_sizes'],
        out_dir=lambda wildcards, output: os.path.dirname(output.corrected_bw)

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/{sample}_atacorrect.err"
    benchmark: "benchmarks/tobias/{sample}_atacorrect.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.17.3--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS ATACorrect] Sample: {wildcards.sample} | BAM: {input.bam} | Peaks: {input.peaks} | Genome: {input.genome}"

    shell:
        """
        mkdir -p "$(dirname {output.corrected_bw})"
        mkdir -p "$(dirname {output.bias_track})"
        mkdir -p "$(dirname {output.log_file})"

        if [ ! -s {input.peaks} ] || [ $(wc -l < {input.peaks}) -eq 0 ]; then
            echo "[WARNING] No peaks found in {input.peaks}. Creating dummy bigWig files." >> {log}
            python3 -c "
import pyBigWig
headers = []
with open('{params.genome_sizes}') as f:
    for line in f:
        if line.strip():
            parts = line.strip().split()
            headers.append((parts[0], int(parts[1])))
for out_path in ['{output.corrected_bw}', '{output.bias_track}']:
    bw = pyBigWig.open(out_path, 'w')
    bw.addHeader(headers)
    bw.addEntries([headers[0][0]], [0], ends=[100], values=[0.0])
    bw.close()
"
            echo "No regions found - dummy created" > {output.log_file}
        else
            TOBIAS ATACorrect \
                --bam {input.bam} \
                --genome {input.genome} \
                --peaks {input.peaks} \
                --blacklist {input.blacklist} \
                --outdir {params.out_dir} \
                --prefix {wildcards.sample} \
                --cores {threads} \
                > {output.log_file} 2>&1

            cp {output.log_file} {log}

            # If output files are not in the exact target path, move them
            if [ "{params.out_dir}/{wildcards.sample}_corrected.bw" != "{output.corrected_bw}" ]; then
                mv {params.out_dir}/{wildcards.sample}_corrected.bw {output.corrected_bw}
            fi
            if [ "{params.out_dir}/{wildcards.sample}_bias.bw" != "{output.bias_track}" ]; then
                mv {params.out_dir}/{wildcards.sample}_bias.bw {output.bias_track}
            fi
        fi
        """

rule tobias_score_bigwig:
    input:
        corrected_bw=lambda wildcards: f"{config['tobias']['output']['corrected_bw']}/{wildcards.sample}_corrected.bw",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"

    output:
        footprint_bw=f"{config['tobias']['output']['footprint_bw']}/{{sample}}_footprints.bw"

    params:
        out_dir=lambda wildcards, output: os.path.dirname(output.footprint_bw),
        genome_sizes=config['global']['references']['genome_sizes']

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/{sample}_score.err"
    benchmark: "benchmarks/tobias/{sample}_score.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.17.3--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS FootprintScores] Sample: {wildcards.sample} | BigWig: {input.corrected_bw} | Peaks: {input.peaks}"

    shell:
        """
        if [ ! -s {input.peaks} ] || [ $(wc -l < {input.peaks}) -eq 0 ]; then
            echo "[WARNING] No peaks found in {input.peaks}. Creating dummy footprint bigWig file." >> {log}
            python3 -c "
import pyBigWig
headers = []
with open('{params.genome_sizes}') as f:
    for line in f:
        if line.strip():
            parts = line.strip().split()
            headers.append((parts[0], int(parts[1])))
bw = pyBigWig.open('{output.footprint_bw}', 'w')
bw.addHeader(headers)
bw.addEntries([headers[0][0]], [0], ends=[100], values=[0.0])
bw.close()
"
        else
            TOBIAS FootprintScores \
                --signal {input.corrected_bw} \
                --regions {input.peaks} \
                --output {output.footprint_bw} \
                --cores {threads} \
                2> {log}
        fi
        """

rule tobias_bindetect:
    input:
        corrected_bw=expand("{path}/{sample}_corrected.bw", path=config['tobias']['output']['corrected_bw'], sample=SAMPLES),
        peaks=f"{config['consensus_peaks']['output']['consensus']}/consensus_peaks.bed",
        genome=config['tobias']['params']['genome_fa'],
        motif_db=config['tobias']['params']['motif_db'],
        sample_sheet=config['global']['samples']

    output:
        bindetect_dir=directory(config['tobias']['output']['bindetect'])

    params:
        conditions=config['tobias']['params']['conditions'],
        genome_sizes=config['tobias']['params']['genome_sizes'],
        corrected_bw_dir=lambda wildcards, input: os.path.dirname(input.corrected_bw[0]),
        n_bams=lambda wildcards, input: len(input.corrected_bw),
        signals_flag=lambda wildcards, input: " ".join([f"--signals {bw}" for bw in input.corrected_bw])

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/bindetect.err"
    benchmark: "benchmarks/tobias/bindetect.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.17.3--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS BINDetect] Running differential TF binding analysis on {params.n_bams} samples"

    shell:
        """
        if [ ! -s {input.peaks} ] || [ $(wc -l < {input.peaks}) -eq 0 ]; then
            echo "[WARNING] No peaks found in consensus peaks file {input.peaks}. Creating empty bindetect directory." >> {log}
            mkdir -p {output.bindetect_dir}
        else
            TOBIAS BINDetect \
                {params.signals_flag} \
                --motifs {input.motif_db} \
                --genome {input.genome} \
                --peaks {input.peaks} \
                --outdir {output.bindetect_dir} \
                --cores {threads} \
                2> {log}
        fi
        """
