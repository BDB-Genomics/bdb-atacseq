import os
rule tss_enrichment:
    input: 
        shifted_bam=lambda wildcards: f"{config['tss_enrichment']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam", 
        shifted_bam_index=lambda wildcards: f"{config['tss_enrichment']['input']['shifted_bam_index']}/{wildcards.sample}.filtered.shifted.bam.bai"
        
    output:
        text=f"{config['tss_enrichment']['output']}/{{sample}}_tss_enrichment.txt", 
        pdf=f"{config['tss_enrichment']['output']}/{{sample}}_tss_enrichment.pdf"
        
    params:
        annotation=config['tss_enrichment']['params']['annotation'], 
        upstream=config['tss_enrichment']['params']['upstream'], 
        downstream=config['tss_enrichment']['params']['downstream']
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['tss_enrichment']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['tss_enrichment']['resources']['time'] * attempt,
  
    log: "logs/tss_enrichment/{sample}.err"
    benchmark: "benchmarks/tss_enrichment/{sample}.txt"
    conda: "envs/04_metrics_qc/tss_enrichment.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-atacseqqc:1.22.0--r42hdfd78af_0"
    threads: config['tss_enrichment']['threads']
    message: "[TSS ENRICHMENT] SAMPLE: {wildcards.sample}| INPUT: {input.shifted_bam} {input.shifted_bam_index} | OUTPUT: {output.text} {output.pdf}| ANNOTATION: {params.annotation}| UPSTREAM: {params.upstream}| DOWNSTREAM: {params.downstream}  "
        
    script:
        "scripts/tss_enrichment.R"
