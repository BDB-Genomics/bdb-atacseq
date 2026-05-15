
rule bowtie2_align: 
    input:
        R1_fastp=lambda wildcards: f"{config['bowtie2']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz", 
        R2_fastp=lambda wildcards: f"{config['bowtie2']['input']}/{wildcards.sample}_R2_trimmed.fastq.gz"
        
    output:
        BAM=f"{config[ 'bowtie2']['output']}/{{sample}}.bam"
        
    params:
        index = config['bowtie2']['params']['index'],         
            
    resources:
        mem_mb=config['bowtie2']['resources']['mem_mb'], 
        time=config['bowtie2']['resources']['time']
        

    log: "logs/bowtie2/{sample}.err" 
    conda: "envs/02_alignment/bowtie2.yaml" 
    threads: config['bowtie2']['threads']
    message: "[BOWTIE2 ALIGN] SAMPLE: {wildcards.sample} |INPUT: {input.R1_fastp} {input.R2_fastp}|OUTPUT: {output.BAM}|PARAMS: {params.index}" 

    benchmark: 
        "benchmarks/bowtie2/{sample}.txt"
        
        
    shell:
        r"""
        set -o pipefail 
        bowtie2 -x {params.index} \
                -1 {input.R1_fastp} \
                -2 {input.R2_fastp} \
                --very-sensitive \
                -p {threads} \
                2> {log} | \
        samtools view -@ {threads} -Sb -F 4 -f 2 - > {output.BAM} 2>> {log}
        """
         
         
         
   
