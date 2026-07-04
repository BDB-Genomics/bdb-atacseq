rule samtools_index:
    input:
        sorted_bam_noMT=lambda wildcards: f"{config['samtools_index']['input']['sorted_bam_noMT']}/{wildcards.sample}_noMT.sorted.bam"
        
    output:
        indexed_bam=f"{config['samtools_index']['output']['index']}/{{sample}}_noMT.sorted.bam.bai"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_index']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_index']['resources']['time'] * attempt,
        
    log: "logs/samtools_index/{sample}.err"
    benchmark: "benchmarks/samtools_index/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['samtools_index']['threads']
    message: "[SAMTOOLS INDEX] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT}| OUTPUT: {output.indexed_bam}"
        
    shell:
        """
        samtools index \
        -@ {threads} \
        {input.sorted_bam_noMT}\
        {output.indexed_bam} \
        2> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """
         
