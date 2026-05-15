rule remove_mito_reads:
    input:
        sorted_bam=lambda wildcards: f"{config['remove_mito_reads']['input']['sorted_bam']}/{wildcards.sample}.sorted.bam"
    
    output:
        noMT_sorted_bam=f"{config['remove_mito_reads']['output']['noMT_sorted_bam']}/{{sample}}_noMT.sorted.bam"
        
    params:
        mito_chr=config['remove_mito_reads']['params']['mito_chr'], 
        validation_input=True
        
    resources:
        mem_mb=config['remove_mito_reads']['resources']['mem_mb'], 
        time=config['remove_mito_reads']['resources']['time']
        
    benchmark:
        "benchmarks/remove_mito_reads/{sample}_noMT_sorted_bam.txt"

    log:
        "logs/remove_mito_reads/{sample}_noMT_sorted_bam.err"

    conda:
        "envs/03_post_alignment/samtools.yaml"

    threads:
        config['remove_mito_reads']['threads']

    message:
        "[REMOVE MITOCHONDRIAL READS] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam}|OUTPUT: {output.noMT_sorted_bam}| PATTERN: {params.mito_chr}|" 

    shell:
        """
        samtools view -h {input.sorted_bam} | \
        awk -v mito_chr="{params.mito_chr}" 'BEGIN {{OFS="\\t"}} /^@/ || $3 !~ mito_chr {{print $0}}' | \
        samtools sort -@ {threads} -o {output.noMT_sorted_bam} -
        
        echo "Complete mitochondrial removal for {wildcards.sample}" &>> {log}
        """
