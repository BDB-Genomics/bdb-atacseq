rule tobias_atacorrect:
    input:
        bam=lambda wildcards: f"{config['tobias']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam",
        genome=config['tobias']['params']['genome_fa'],
        blacklist=config['tobias']['params']['blacklist']

    output:
        corrected_bam=f"{config['tobias']['output']['corrected_bam']}/{{sample}}_corrected.bam",
        bias_track=f"{config['tobias']['output']['bias_track']}/{{sample}}_bias.bw",
        log_file=f"{config['tobias']['output']['logs']}/{{sample}}_atacorrect.log"

    params:
        genome_sizes=config['tobias']['params']['genome_sizes'],
        blacklist=config['tobias']['params']['blacklist']

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/{sample}_atacorrect.err"
    benchmark: "benchmarks/tobias/{sample}_atacorrect.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.14.2--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS ATACorrect] Sample: {wildcards.sample} | BAM: {input.bam} | Genome: {input.genome}"

    shell:
        """
        TOBIAS ATACorrect \
            --bam {input.bam} \
            --genome {input.genome} \
            --blacklist {params.blacklist} \
            --outdir {config['tobias']['output']['corrected_bam']} \
            --prefix {wildcards.sample} \
            --cores {threads} \
            2> {log}

        mv {config['tobias']['output']['corrected_bam']}/{wildcards.sample}_corrected.bam {output.corrected_bam}
        mv {config['tobias']['output']['corrected_bam']}/{wildcards.sample}_bias.bw {output.bias_track}
        mv {config['tobias']['output']['corrected_bam']}/{wildcards.sample}_atacorrect.log {output.log_file}
        """

rule tobias_score_bigwig:
    input:
        bam=lambda wildcards: f"{config['tobias']['output']['corrected_bam']}/{wildcards.sample}_corrected.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        genome=config['tobias']['params']['genome_fa'],
        motif_db=config['tobias']['params']['motif_db']

    output:
        footprint_bw=f"{config['tobias']['output']['footprint_bw']}/{{sample}}_footprints.bw",
        regions=f"{config['tobias']['output']['regions']}/{{sample}}_scored_regions.bed"

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/{sample}_score.err"
    benchmark: "benchmarks/tobias/{sample}_score.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.14.2--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS ScoreBigwig] Sample: {wildcards.sample} | BAM: {input.bam} | Peaks: {input.peaks}"

    shell:
        """
        TOBIAS ScoreBigwig \
            --bam {input.bam} \
            --peaks {input.peaks} \
            --genome {input.genome} \
            --motifs {input.motif_db} \
            --outdir {config['tobias']['output']['footprint_bw']} \
            --prefix {wildcards.sample} \
            --cores {threads} \
            2> {log}

        mv {config['tobias']['output']['footprint_bw']}/{wildcards.sample}_footprints.bw {output.footprint_bw}
        mv {config['tobias']['output']['footprint_bw']}/{wildcards.sample}_regions.bed {output.regions}
        """

rule tobias_bindetect:
    input:
        bam=expand("{path}/{sample}_corrected.bam", path=config['tobias']['output']['corrected_bam'], sample=SAMPLES),
        peaks=config['consensus_peaks']['output']['consensus'] + "/consensus_peaks.bed",
        genome=config['tobias']['params']['genome_fa'],
        motif_db=config['tobias']['params']['motif_db'],
        sample_sheet=config['global']['samples']

    output:
        bindetect_dir=directory(config['tobias']['output']['bindetect'])

    params:
        conditions=config['tobias']['params']['conditions'],
        genome_sizes=config['tobias']['params']['genome_sizes']

    resources:
        mem_mb=config['tobias']['resources']['mem_mb'],
        time=config['tobias']['resources']['time']

    log: "logs/tobias/bindetect.err"
    benchmark: "benchmarks/tobias/bindetect.txt"
    conda: "envs/05_peak_calling/tobias.yaml"
    container: "https://depot.galaxyproject.org/singularity/tobias:0.14.2--pyhdfd78af_0"
    threads: config['tobias']['threads']
    message: "[TOBIAS BINDetect] Running differential TF binding analysis on {len(input.bam)} samples"

    shell:
        """
        # Build sample list from sample sheet
        SAMPLES_FLAG=""
        while IFS=$'\\t' read -r sample fastq_r1 fastq_r2 replicate condition; do
            if [ "$sample" != "sample" ]; then
                SAMPLES_FLAG="$SAMPLES_FLAG --bam {config['tobias']['output']['corrected_bam']}/${{sample}}_corrected.bam"
            fi
        done < {input.sample_sheet}

        TOBIAS BINDetect \\
            $SAMPLES_FLAG \\
            --motifs {input.motif_db} \\
            --genome {input.genome} \\
            --peaks {input.peaks} \\
            --outdir {output.bindetect_dir} \\
            --cores {threads} \\
            2> {log}
        """
