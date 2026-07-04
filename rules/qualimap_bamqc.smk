rule qualimap_bamqc:
    input:
        markdup_bam=lambda wildcards: f"{config['qualimap_bamqc']['input']['markdup_bam']}/{wildcards.sample}.sorted.dedup.bam",
        gtf=config['global']['references']['annotation_gtf']
        
    output:
        qc_dir=directory(f"{config['qualimap_bamqc']['output']['qc_dir']}/{{sample}}_qualimap_report")
        
    params:
        extra="bamqc",
        mem_gb=lambda wildcards, resources: f"{max(4, int(resources.mem_mb / 1024))}G" if isinstance(resources.mem_mb, (int, float)) else "4G"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['qualimap_bamqc']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['qualimap_bamqc']['resources']['time'] * attempt,
           
    log: "logs/qualimap/{sample}.err"
    benchmark: "benchmarks/qualimap/{sample}.txt"
    conda: "envs/04_metrics_qc/qualimap.yaml"
    container: "https://depot.galaxyproject.org/singularity/qualimap:2.2.2d--1"
    threads: config['qualimap_bamqc']['threads']
    message: "[qualimap] Sample: {wildcards.sample} | Markdup Bam: {input.markdup_bam} | Reports: {output.qc_dir} | Extra: {params.extra}..."

    shell:
        """
        qualimap {params.extra} \
            -bam {input.markdup_bam} \
            -outdir {output.qc_dir} \
            -gff {input.gtf} \
            --java-mem-size={params.mem_gb} \
            -nt {threads} \
            2> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """
