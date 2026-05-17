rule picard_CollectAlignmentSummaryMetrics:
    input:
        markdup_bam=lambda wildcards:f"{config['picard']['alignment_metrics']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
        
    output:
        alignment_metrics=f"{config['picard']['alignment_metrics']['output']['alignment_metrics']}/{{sample}}.alignment_metrics.txt"
        
    params:
        reference_genome=ancient(config['picard']['alignment_metrics']['params']['reference_genome']), 
        validation_stringency=config['picard']['alignment_metrics']['params']['validation_stringency']
                
    resources:
        mem_mb=config['picard']['alignment_metrics']['resources']['mem_mb'], 
        time=config['picard']['alignment_metrics']['resources']['time']

    log: "logs/picard/CollectAlignmentSummaryMetrics/{sample}.err"
    benchmark: "benchmarks/picard/CollectAlignmentSummaryMetrics/{sample}.txt"
    conda: "envs/04_metrics_qc/picard.yaml"
    container: "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1"
    threads: config['picard']['alignment_metrics']['threads']
    message: "[PICARD COLLECTALIGNMENTSUMMARYMETRICS] SAMPLE: {wildcards.sample}| INPUT: {input.markdup_bam}| OUTPUT: {output.alignment_metrics}| REFERENCE GENOME: {params.reference_genome}| VALIDATION STRINGENCY: {params.validation_stringency}."

    shell:
        """
        PICARD_VERSION=$(picard --help 2>&1 | head -n 1 || echo "Picard Version Unknown" )
        echo "PICARD VERSION: ${{PICARD_VERSION}}" >> {log}
        
        set +e
        picard CollectAlignmentSummaryMetrics \
            --INPUT {input.markdup_bam} \
            --OUTPUT {output.alignment_metrics} \
            --REFERENCE_SEQUENCE {params.reference_genome} \
            --VALIDATION_STRINGENCY {params.validation_stringency} \
            2>> {log} 
        EXIT_STATUS=$?
        set -e

        if [ "${{EXIT_STATUS}}" -eq 0 ]; then 
           echo "SUCCESSFUL; EXIT STATUS: ${{EXIT_STATUS}}" >> {log}
        else 
           echo "UNSUCCESSFUL; EXIT STATUS: ${{EXIT_STATUS}}" >> {log}
           exit ${{EXIT_STATUS}}
        fi  
        """   
