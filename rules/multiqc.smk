if MODE == "bulk":
    multiqc_inputs = [
        expand("{path}/{sample}_R1_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}_R2_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}.json", path=config['fastp']['output'], sample=SAMPLES),
        expand("{path}/{sample}_qc_pass.json", path=config['qc_gate']['output'], sample=SAMPLES),
        expand("{path}/{sample}_postFiltering.stats.txt", path=config['samtools_stats']['output']['stats'], sample=SAMPLES),
        expand("{path}/{sample}.alignment_metrics.txt", path=config['picard']['alignment_metrics']['output']['alignment_metrics'], sample=SAMPLES),
        expand("{path}/{sample}.insert_metrics.txt", path=config['picard']['insert_metrics']['output']['metrics'], sample=SAMPLES),
        expand("{path}/{sample}.insert_histogram.pdf", path=config['picard']['insert_metrics']['output']['histogram'], sample=SAMPLES),
    ] + ([] if config.get("ci_mode", False) else [
        expand("{path}/{sample}.ccurve.txt", path=config['preseq']['output']['predicted_complexity'], sample=SAMPLES),
    ]) + [
        expand("{path}/{sample}_qualimap_report", path=config['qualimap_bamqc']['output']['qc_dir'], sample=SAMPLES),
    ]
else:  # scatac
    multiqc_inputs = [
        expand("{path}/{sample}_R1_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}_R2_trimmed_fastqc.zip", path=config['fastqc']['output'], sample=SAMPLES),
        expand("{path}/{sample}.json", path=config['fastp']['output'], sample=SAMPLES),
    ]


rule multiqc:
    input:
        multiqc_inputs
        
    output:
        report_html=f"{config['multiqc']['output']}/multiqc_report.html"
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['multiqc']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['multiqc']['resources']['time'] * attempt,

    log: "logs/multiqc/multiqc.err"
    conda: "envs/01_preprocessing/multiqc.yaml"
    container: "docker://quay.io/biocontainers/multiqc:1.14--pyhdfd78af_0"
    threads: config['multiqc']['threads']
    message: "Running MultiQC to aggregate all QC reports| INPUT: {input}"
        
    params:
        config=config['multiqc']['params']['config'],
        out_dir=lambda wildcards, output: __import__('os').path.dirname(output.report_html)
        
    shell:
        """
        multiqc {input} -f -o {params.out_dir} \
            -c {params.config} \
            --title "ATAC-seq Pipeline QC Report" \
            --comment "Comprehensive quality control metrics for ATAC-seq analysis" \
            2> {log}

        if [ -f "{params.out_dir}/ATAC-seq-Pipeline-QC-Report_multiqc_report.html" ]; then
            mv "{params.out_dir}/ATAC-seq-Pipeline-QC-Report_multiqc_report.html" "{output.report_html}"
        fi
        """
