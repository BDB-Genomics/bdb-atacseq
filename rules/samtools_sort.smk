rule samtools_sort:
    input:
        unsorted_bam=lambda wildcards: f"{config['samtools_sort']['input']['unsorted_bam']}/{wildcards.sample}.bam"
        
    output:
        bam_sorted=f"{config['samtools_sort']['output']['sorted_bam']}/{{sample}}.sorted.bam"
    
    resources:
        mem_mb=config['samtools_sort']['resources']['mem_mb'], 
        time=config['samtools_sort']['resources']['time']
            

    log: "logs/samtools_sort/{sample}.err"
    conda: "envs/03_post_alignment/samtools.yaml" 
    threads: config["samtools_sort"]["threads"] 
    message: "[SAMTOOLS SORT] SAMPLE: {wildcards.sample}| INPUT: {input.unsorted_bam}| OUTPUT: {output.bam_sorted}" 

    benchmark:
        "benchmarks/samtools_sort/{sample}.txt"
        
      
    shell:
        """
        samtools sort \
        -@ {threads} \
        -O BAM \
        -o {output.bam_sorted} \
        {input.unsorted_bam}
        2> {log} 
        """
        
        
        
