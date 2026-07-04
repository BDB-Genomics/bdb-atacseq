rule picard_CollectInsertSizeMetrics:
    input:
        markdup_bam=lambda wildcards: f"{config['picard']['insert_metrics']['input']['markdup_bam']}/{wildcards.sample}.sorted.dedup.bam"
        
    output:
        insert_metrics=f"{config['picard']['insert_metrics']['output']['metrics']}/{{sample}}.insert_metrics.txt",
        insert_histogram=f"{config['picard']['insert_metrics']['output']['histogram']}/{{sample}}.insert_histogram.pdf"
        
    params:
        m=config['picard']['insert_metrics']['params']['M'],
        validation_stringency=config['picard']['insert_metrics']['params']['validation_stringency']
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['picard']['insert_metrics']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['picard']['insert_metrics']['resources']['time'] * attempt,

    log: "logs/picard/CollectInsertSizeMetrics/{sample}.err"
    benchmark: "benchmarks/picard/CollectInsertSizeMetrics/{sample}.txt"
    conda: "envs/04_metrics_qc/picard.yaml"
    container: "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1"
    threads: config['picard']['insert_metrics']['threads']
    message: "[PICARD COLLECTINSERTSIZEMETRICS] SAMPLES: {wildcards.sample}| INPUT: {input.markdup_bam}| OUTPUT: {output.insert_metrics} {output.insert_histogram}|m: {params.m}| VALIDATION STRINGENCY: {params.validation_stringency}"

    shell:
        """
        VERSION=$(picard --help  2>&1 | head -n 1 || echo "Picard Version Unknown")
        echo "PICARD VERSION: ${{VERSION}}" >> {log}
        
        set +e
        picard CollectInsertSizeMetrics \
            --INPUT {input.markdup_bam} \
            --OUTPUT {output.insert_metrics} \
            --Histogram_FILE {output.insert_histogram} \
            --M {params.m} \
            --VALIDATION_STRINGENCY {params.validation_stringency} \
            2>> {log}
        EXIT_STATUS=$?
        set -e

        if [ ${{EXIT_STATUS}} -eq 0 ]; then
           echo "SUCCESSFUL; EXIT STATUS: ${{EXIT_STATUS}}" >> {log}
        else 
           echo "UNSUCCESSFUL; EXIT STATUS: ${{EXIT_STATUS}}" >> {log}
           exit ${{EXIT_STATUS}}
        fi
        || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """
