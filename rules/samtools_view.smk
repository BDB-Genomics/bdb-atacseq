rule samtools_view:
    input:
        dedup_bam=lambda wildcards: f"{config['samtools_view']['input']['noMT_sorted_bam']}/{wildcards.sample}_noMT.sorted.bam"
        
    output:
        filtered_bam=f"{config['samtools_view']['output']['filtered_bam']}/{{sample}}.filtered.pre_blacklist.bam"
    
    params:
        minimum_mapq=config['samtools_view']['params']['MAPQ'], 
        filter_flags=config['samtools_view']['params']['flags']
    
    resources:
        mem_mb=config['samtools_view']['resources']['mem_mb'], 
        time=config['samtools_view']['resources']['time']            

    log: "logs/samtools_view/{sample}.out"
    benchmark: "benchmarks/samtools_view/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['samtools_view']['threads']
    message: "[SAMTOOLS VIEW] SAMPLE: {wildcards.sample} | INPUT: {input.dedup_bam} | OUTPUT: {output.filtered_bam}| MINIMUM MAPQ: {params.minimum_mapq} | FILTER FLAGS: {params.filter_flags}"
        
    shell:
        """
        samtools view \
        -@ {threads} \
        -b \
        -q {params.minimum_mapq} \
        -F {params.filter_flags} \
        -f 2 \
        {input.dedup_bam} \
        -o {output.filtered_bam} \
        2> {log}
        """

   
