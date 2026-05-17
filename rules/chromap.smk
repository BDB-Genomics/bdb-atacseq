rule chromap_align:
    input:
        R1_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz",
        R2_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R2_trimmed.fastq.gz",
        index=config['chromap']['params']['index']

    output:
        BAM=f"{config['chromap']['output']}/{{sample}}.bam",
        tagBam=f"{config['chromap']['output']}/{{sample}}_tag.bam"

    params:
        preset=config['chromap']['params']['preset'],
        barcode_regex=config['chromap']['params'].get('barcode_regex', None),
        extra=config['chromap']['params'].get('extra', '')

    resources:
        mem_mb=config['chromap']['resources']['mem_mb'],
        time=config['chromap']['resources']['time']

    log: "logs/chromap/{sample}.err"
    benchmark: "benchmarks/chromap/{sample}.txt"
    conda: "envs/02_alignment/chromap.yaml"
    container: "https://depot.galaxyproject.org/singularity/chromap:0.2.6--h9ee545e_1"
    threads: config['chromap']['threads']
    message: "[CHROMAP] Sample: {wildcards.sample} | Mode: scATAC-seq | Preset: {params.preset}"

    shell:
        """
        chromap \
            --preset {params.preset} \
            -x {input.index} \
            -r {config['global']['references']['genome_fa']} \
            -1 {input.R1_fastp} \
            -2 {input.R2_fastp} \
            -t {threads} \
            --drop-seq \
            {params.extra} \
            -o {output.BAM} \
            --SAM \
            2> {log}

        samtools view -bS {output.BAM} > {output.tagBam} 2>> {log}
        """
