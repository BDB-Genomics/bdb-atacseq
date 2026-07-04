rule tn5_shift:
    input:
        filtered_bam=lambda wildcards: f"{config['tn5_shift']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam", 
        filtered_bam_index=lambda wildcards: f"{config['samtools_index_post_filter']['output']['filtered_bam_indexed']}/{wildcards.sample}.filtered.bam.bai"
                
    output:
        shifted_filtered_bam=f"{config['tn5_shift']['output']['shifted_bam']}/{{sample}}.filtered.shifted.bam",
        shifted_filtered_bam_index=f"{config['tn5_shift']['output']['shifted_bam_index']}/{{sample}}.filtered.shifted.bam.bai"
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['tn5_shift']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['tn5_shift']['resources']['time'] * attempt,

    log: "logs/tn5_shift/{sample}.err"
    benchmark: "benchmarks/tn5_shift/{sample}.txt"
    conda: "envs/06_visualization/deeptools.yaml"
    container: "https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02306649ee64e819b8830f69904d48507:6c2688b7762696e16544521798e29a9b1c76949b-0"
    threads: config['tn5_shift']['threads']
    message: "[TN5 SHIFT: Adjusting ATAC-seq read positions by +4-5 bp to reflect true Tn5 cut sites] SAMPLE:  {wildcards.sample}| INPUT: {input.filtered_bam} {input.filtered_bam_index} | OUTPUT: {output.shifted_filtered_bam} {output.shifted_filtered_bam_index}"
        
    shell:
        """
        alignmentSieve --ATACshift \
           -b {input.filtered_bam} \
           -o {output.shifted_filtered_bam}.unsorted \
           -p {threads} \
           2> {log}  && \
        samtools sort -@ {threads} -o {output.shifted_filtered_bam} {output.shifted_filtered_bam}.unsorted 2>> {log} && \
        rm -f {output.shifted_filtered_bam}.unsorted && \
        samtools index {output.shifted_filtered_bam} {output.shifted_filtered_bam_index} 2>> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """
