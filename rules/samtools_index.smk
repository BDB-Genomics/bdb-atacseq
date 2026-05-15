rule samtools_index:
    input:
        sorted_bam_noMT=lambda wildcards: f"{config['samtools_index']['input']['sorted_bam_noMT']}/{wildcards.sample}_noMT.sorted.bam"
        
    output:
        indexed_bam=f"{config['samtools_index']['output']['index']}/{{sample}}_noMT.sorted.bam.bai"

    resources:
        mem_mb=config['samtools_index']['resources']['mem_mb'], 
        time=config['samtools_index']['resources']['time']     
        

    log: "logs/samtools_index/{sample}.err" 
    conda: "envs/03_post_alignment/samtools.yaml" 
    threads: config['samtools_index']['threads'] 
    message: "[SAMTOOLS INDEX] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT}| OUTPUT: {output.indexed_bam}" 

    benchmark:
        "benchmarks/samtools_index/{sample}.txt"
        
    shell:
        """
        samtools index \
        -@ {threads} \
        {input.sorted_bam_noMT}\
        {output.indexed_bam} \
        2> {log}
        """
         
