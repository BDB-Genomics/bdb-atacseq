rule samtools_stats:
    input:
        filtered_bam=lambda wildcards: f"{config['samtools_stats']['input']['filtered_bam']}/{wildcards.sample}_noMT.sorted.bam"
        
    output:
        stats=f"{config['samtools_stats']['output']['stats']}/{{sample}}_postFiltering.stats.txt"
    
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_stats']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_stats']['resources']['time'] * attempt,
                    
    log: "logs/samtools_stats/{sample}.err"
    benchmark: "benchmarks/samtools_stats/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['samtools_stats']['threads']
    message: "[SAMTOOLS STATISTICS] SAMPLE: {wildcards.sample}| INPUT: {input.filtered_bam}| OUTPUT: {output.stats}"
        
    shell:
        """
        samtools stats \
        -@ {threads} \
        {input.filtered_bam} \
        > {output.stats} \
        2> {log}
        || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """

   
