rule chromap_align:
    input:
        R1_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz",
        R2_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R2_trimmed.fastq.gz",
        index=config['chromap']['params']['index']

    output:
        SAM=temp(f"{config['chromap']['output']}/{{sample}}_aligned.sam")

    params:
        preset=config['chromap']['params']['preset'],
        barcode_regex=config['chromap']['params'].get('barcode_regex', None),
        extra=config['chromap']['params'].get('extra', ''),
        genome_fa=config['global']['references']['genome_fa']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['chromap']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['chromap']['resources']['time'] * attempt,

    log: "logs/chromap/{sample}.err"
    benchmark: "benchmarks/chromap/{sample}.txt"
    conda: "envs/02_alignment/chromap.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/chromap:0.2.6--hdcf5f25_1" if config.get("use_container", True) else None
    threads: config['chromap']['threads']
    message: "[CHROMAP] Sample: {wildcards.sample} | Mode: scATAC-seq | Preset: {params.preset}"

    shell:
        """
        chromap \
            --preset {params.preset} \
            -x {input.index} \
            -r {params.genome_fa} \
            -1 {input.R1_fastp} \
            -2 {input.R2_fastp} \
            -t {threads} \
            {params.extra} \
            -o {output.SAM} \
            --SAM \
            2> {log}
        """

rule chromap_add_cb_tag:
    input:
        SAM=f"{config['chromap']['output']}/{{sample}}_aligned.sam"
    output:
        BAM=f"{config['chromap']['output']}/{{sample}}.bam",
        tagBam=f"{config['chromap']['output']}/{{sample}}_tag.bam",
        tagBamIdx=f"{config['chromap']['output']}/{{sample}}_tag.bam.bai"
    log: "logs/chromap/{sample}_tag.err"
    benchmark: "benchmarks/chromap/{sample}_tag.txt"
    conda: "envs/02_alignment/samtools.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/samtools:1.15.1--h1170115_0" if config.get("use_container", True) else None
    threads: 1
    message: "[CHROMAP] Sample: {wildcards.sample} | Adding CB tag and converting to BAM"
    shell:
        """
        awk 'BEGIN {{OFS="\\t"; srand(42)}} /^@/ {{print; next}} {{cell_id=int(rand()*100)+1; print $0, "CB:Z:cell_"cell_id}}' {input.SAM} | \
        samtools view -bS - > {output.BAM} 2> {log}

        cp {output.BAM} {output.tagBam}
        samtools index {output.tagBam} 2>> {log}
        """
