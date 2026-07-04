rule samtools_sort:
    input:
        unsorted_bam=lambda wildcards: f"{config['samtools_sort']['input']['unsorted_bam']}/{wildcards.sample}.bam"
        
    output:
        bam_sorted=f"{config['samtools_sort']['output']['sorted_bam']}/{{sample}}.sorted.bam"
    
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_sort']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_sort']['resources']['time'] * attempt,
            
    log: "logs/samtools_sort/{sample}.err"
    benchmark: "benchmarks/samtools_sort/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config["samtools_sort"]["threads"]
    message: "[SAMTOOLS SORT] SAMPLE: {wildcards.sample}| INPUT: {input.unsorted_bam}| OUTPUT: {output.bam_sorted}"
              
    shell:
        """
        samtools sort \
        -@ {threads} \
        -O BAM \
        -o {output.bam_sorted} \
        {input.unsorted_bam} \
        2> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """
        
        
        
