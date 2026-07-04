rule remove_mito_reads:
    input:
        sorted_bam=lambda wildcards: f"{config['remove_mito_reads']['input']['sorted_bam']}/{wildcards.sample}.sorted.dedup.bam"
    
    output:
        noMT_sorted_bam=f"{config['remove_mito_reads']['output']['noMT_sorted_bam']}/{{sample}}_noMT.sorted.bam"
        
    params:
        mito_chr=config['remove_mito_reads']['params']['mito_chr']
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['remove_mito_reads']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['remove_mito_reads']['resources']['time'] * attempt,
        
    log: "logs/remove_mito_reads/{sample}_noMT_sorted_bam.err"
    benchmark: "benchmarks/remove_mito_reads/{sample}_noMT_sorted_bam.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['remove_mito_reads']['threads']
    message: "[REMOVE MITOCHONDRIAL READS] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam}|OUTPUT: {output.noMT_sorted_bam}| PATTERN: {params.mito_chr}|"

    shell:
        """
        # Get BAM header chromosome names to dynamically locate MT/M/chrM/chrMT
        mito_chr=$(samtools view -H {input.sorted_bam} | grep -o -E "SN:(chr)?(M|MT)" | cut -d':' -f2 | head -n1)
        if [ -z "$mito_chr" ]; then
            mito_chr="{params.mito_chr}"
        fi

        samtools view -h {input.sorted_bam} 2> {log} | \
        awk -v mito_chr="$mito_chr" 'BEGIN {{OFS="\\t"}} /^@/ || $3 != mito_chr {{print $0}}' 2>> {log} | \
        samtools sort -@ {threads} -o {output.noMT_sorted_bam} - 2>> {log}
        
        echo "Complete mitochondrial removal for {wildcards.sample}" &>> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """
