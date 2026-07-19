rule bowtie2_align: 
    input:
        R1_fastp=lambda wildcards: f"{config['bowtie2']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz", 
        R2_fastp=lambda wildcards: f"{config['bowtie2']['input']}/{wildcards.sample}_R2_trimmed.fastq.gz"
        
    output:
        BAM=f"{config['bowtie2']['output']}/{{sample}}.bam"
        
    params:
        index = config['bowtie2']['params']['index'],
        sensitive = config['bowtie2']['params']['sensitive'],
            
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['bowtie2']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['bowtie2']['resources']['time'] * attempt,
        

    log: "logs/bowtie2/{sample}.err"
    benchmark: "benchmarks/bowtie2/{sample}.txt"
    conda: "envs/02_alignment/bowtie2.yaml"
    container: "docker://quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:a0ffedb52808e102887f6ce600d092675bf3528a-0"
    threads: config['bowtie2']['threads']
    message: "[BOWTIE2 ALIGN] SAMPLE: {wildcards.sample} |INPUT: {input.R1_fastp} {input.R2_fastp}|OUTPUT: {output.BAM}|PARAMS: {params.index}"
        
    shell:
        r"""
        set -o pipefail 
        bowtie2 -x {params.index} \
                -1 {input.R1_fastp} \
                -2 {input.R2_fastp} \
                {params.sensitive} \
                -p {threads} \
                2> {log} | \
        samtools view -@ {threads} -Sb - > {output.BAM} 2>> {log}
        """
         
         
         
   
