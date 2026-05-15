rule tss_enrichment:
    input: 
        shifted_bam=lambda wildcards: f"{config['tss_enrichment']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam", 
        shifted_bam_index=lambda wildcards: f"{config['tss_enrichment']['input']['shifted_bam_index']}/{wildcards.sample}.filtered.shifted.bam.bai"
        
    output:
        text=f"{config['tss_enrichment']['output']}/{{sample}}_tss_enrichment.txt", 
        pdf=f"{config['tss_enrichment']['output']}/{{sample}}_tss_enrichment.pdf"
        
    params:
        txdb=config['tss_enrichment']['params']['txdb'], 
        upstream=config['tss_enrichment']['params']['upstream'], 
        downstream=config['tss_enrichment']['params']['downstream']
        
    resources:
        mem_mb=config['tss_enrichment']['resources']['mem_mb'], 
        time=config['tss_enrichment']['resources']['time']
  
    log: "logs/tss_enrichment/{sample}.err"
    benchmark: "benchmarks/tss_enrichment/{sample}.txt"
    conda: "envs/04_metrics_qc/tss_enrichment.yaml"
    container: "https://depot.galaxyproject.org/singularity/r-base:4.2.1"
    threads: config['tss_enrichment']['threads']
    message: "[TSS ENRICHMENT] SAMPLE: {wildcards.sample}| INPUT: {input.shifted_bam} {input.shifted_bam_index} | OUTPUT: {output.text} {output.pdf}| T XDB: {params.txdb}| UPSTREAM: {params.upstream}| DOWNSTREAM: {params.downstream}  "
        
    script:
        config['tss_enrichment']['script']
