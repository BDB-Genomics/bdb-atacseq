rule multiqc:
    input:
        expand("{path}/{sample}_R1_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}_R2_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}.json", path=config['fastp']['output'], sample=SAMPLES),
        expand("{path}/{sample}_postFiltering.stats.txt", path=config['samtools_stats']['output']['stats'], sample=SAMPLES),
        expand("{path}/{sample}.alignment_metrics.txt", path=config['picard']['alignment_metrics']['output']['alignment_metrics'], sample=SAMPLES),
        expand("{path}/{sample}.insert_metrics.txt", path=config['picard']['insert_metrics']['output']['metrics'], sample=SAMPLES),
        expand("{path}/{sample}.insert_histogram.pdf", path=config['picard']['insert_metrics']['output']['histogram'], sample=SAMPLES),
        expand("{path}/{sample}.ccurve.txt", path=config['preseq']['output']['predicted_complexity'], sample=SAMPLES),
        expand("{path}/{sample}_qualimap_report", path=config['qualimap_bamqc']['output']['qc_dir'], sample=SAMPLES)
        
    output:
        report_dir=directory(config['multiqc']['output'])
        
    resources:
        mem_mb=config['multiqc']['resources']['mem_mb'], 
        time=config['multiqc']['resources']['time']

    log: "logs/multiqc/multiqc.err"
    conda: "envs/01_preprocessing/multiqc.yaml"
    threads: config['multiqc']['threads']
    message: "Running MultiQC to aggregate all QC reports| INPUT: {input}"
        
    shell:
        """
        multiqc {input} -o {output.report_dir} \
            --title "ATAC-seq Pipeline QC Report" \
            --comment "Comprehensive quality control metrics for ATAC-seq analysis" \
            2> {log}
        """


