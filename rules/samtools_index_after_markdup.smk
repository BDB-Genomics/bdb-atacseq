rule samtools_index_postmarkdup:
    input:
        markdup_bam=lambda wildcards: f"{config['samtools_index_post_markdup']['input']['markdup_bam']}/{wildcards.sample}.sorted.dedup.bam"
        
    output:
        indexed_markdup_bam=f"{config['samtools_index_post_markdup']['output']['index']}/{{sample}}.sorted.dedup.bam.bai"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_index_post_markdup']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_index_post_markdup']['resources']['time'] * attempt,
             
    log: "logs/samtools_index/post_markdup/{sample}.err"
    benchmark: "benchmarks/samtools_index/post_markdup/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "docker://quay.io/biocontainers/samtools:1.15.1--h1170115_0"
    threads: config['samtools_index_post_markdup']['threads']
    message: "[SAMTOOLS INDEX POST MARKDUP] SAMPLE: {wildcards.sample}| INPUT: {input.markdup_bam}| OUTPUT: {output.indexed_markdup_bam}"
        
    shell:
        """
        samtools index \
        -@ {threads} \
        {input.markdup_bam}\
        {output.indexed_markdup_bam} \
        2> {log}
        """
         
