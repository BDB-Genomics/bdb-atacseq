rule qualimap_bamqc:
    input:
        markdup_bam=lambda wildcards: f"{config['qualimap_bamqc']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam",
        gtf=config['global']['references']['annotation_gtf']
        
    output:
        qc_dir=directory(f"{config['qualimap_bamqc']['output']['qc_dir']}/{{sample}}_qualimap_report")
        
    params:
        extra="bamqc"

    resources:
        mem_mb=config['qualimap_bamqc']['resources']['mem_mb'], 
        time=config['qualimap_bamqc']['resources']['time'] 
           
    log: "logs/qualimap/{sample}.err"
    benchmark: "benchmarks/qualimap/{sample}.txt"
    conda: "envs/04_metrics_qc/qualimap.yaml"
    container: "https://depot.galaxyproject.org/singularity/qualimap:2.2.2d--1"
    threads: config['qualimap_bamqc']['threads']
    message: "[qualimap] Sample: {wildcards.sample} | Markdup Bam: {input.markdup_bam} | Reports: {output.qc_dir} | Extra: {params.extra}..."

    shell:
        """
        # Qualimap memory allocation (dynamic from Snakemake resources)
        mem_gb=$(awk -v m="{resources.mem_mb}" 'BEGIN {printf "%dG", m/1024}')
        if [ "$mem_gb" = "0G" ]; then
            mem_gb="4G"
        fi

        qualimap {params.extra} \
            -bam {input.markdup_bam} \
            -outdir {output.qc_dir} \
            -gff {input.gtf} \
            --java-mem-size=${{mem_gb}} \
            -nt {threads} \
            2> {log}
        """
