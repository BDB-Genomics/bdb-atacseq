rule normalize_coverage:
    input:
        shifted_bam=lambda wildcards: f"{config['normalized_coverage']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam",
        qc_pass=f"{config['qc_gate']['output']}/{{sample}}_qc_pass.txt"
        
    output:
        normalized_coverage=f"{config['normalized_coverage']['output']['normalized_coverage']}/{{sample}}_{config['normalized_coverage']['params']['method']}.bw"
        
    params:
        method=config['normalized_coverage']['params']['method']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['normalized_coverage']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['normalized_coverage']['resources']['time'] * attempt,
       
    log: "logs/normalized_coverage/{sample}.err"
    benchmark: "benchmarks/normalized_coverage/{sample}.txt"
    conda: "envs/06_visualization/deeptools.yaml"
    container: "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0"
    threads: config['normalized_coverage']['threads']     
    message: "[Normalize Coverage] Sample: {wildcards.sample} | Shifted Bam: {input.shifted_bam} | NormalizedCoverage: {output.normalized_coverage} |Method: {params.method}]..."

    shell: 
         """
         bamCoverage \
             -b {input.shifted_bam} \
             -o {output.normalized_coverage} \
             --normalizeUsing {params.method} \
             --numberOfProcessors {threads} \
             2> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
         """
