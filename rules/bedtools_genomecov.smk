rule bedtools_genomecov:
    input:
        shifted_bam=lambda wildcards: f"{config['bedtools_genomecov']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"
 
    output:
        bedgraph=f"{config['bedtools_genomecov']['output']['bedgraph']}/{{sample}}.bedGraph"

    params:
        extra=config['bedtools_genomecov']['params']['extra']

    resources:
        mem_mb=config['bedtools_genomecov']['resources']['mem_mb'], 
        time=config['bedtools_genomecov']['resources']['time']

    log: "logs/bedtools_genomecov/{sample}.err"
    conda: "envs/03_post_alignment/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['bedtools_genomecov']['threads']
    message: "[bedtools genomecov] sample: {wildcards.sample} | BAM : {input.shifted_bam}| Output: {output.bedgraph}..."

    benchmark:
        "benchmarks/bedtools_genomecov/{sample}.txt"

    shell:
        """
        bedtools genomecov \
          -ibam {input.shifted_bam} \
          {params.extra} \
          > {output.bedgraph} \
          2> {log}
        """
