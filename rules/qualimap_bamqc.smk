rule qualimap_bamqc:
    input:
        markdup_bam=lambda wildcards: f"{config['qualimap_bamqc']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
        
    output:
       qc_dir=directory(f"{config['qualimap_bamqc']['output']['qc_dir']}/{{sample}}_qualimap_report")
        
    params:
        extra="bamqc"

    resources:
        mem_mb=config['qualimap_bamqc']['resources']['mem_mb'], 
        time=config['qualimap_bamqc']['resources']['time'] 
           
    benchmark:
        "benchmarks/qualimap/{sample}.txt"
        
    log:
        "logs/qualimap/{sample}.err"
        
    conda:
        "envs/04_metrics_qc/qualimap.yaml"
        
    threads:
        config['qualimap_bamqc']['threads']
        
    message:
        "[qualimap] Sample: {wildcards.sample} | Markdup Bam: {input.markdup_bam} | Reports: {output.qc_dir} | Extra: {params.extra}..."
        
    shell:
        """
        qualimap {params.extra} \
            -bam {input.markdup_bam} \
            -outdir {output.qc_dir} \
            -nt {threads} \
            2> {log}
        """

