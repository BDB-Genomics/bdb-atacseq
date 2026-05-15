rule normalize_coverage:
    input:
        shifted_bam=lambda wildcards: f"{config['normalized_coverage']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"
        
    output:
        normalized_coverage=f"{config['normalized_coverage']['output']['normalized_coverage']}/{{sample}}_CPM.bw"
        
    params:
        method=config['normalized_coverage']['params']['method']

    resources:
        mem_mb=config['normalized_coverage']['resources']['mem_mb'],
        time=config['normalized_coverage']['resources']['time']    
       

    log: "logs/normalized_coverage/{sample}.err"
    container: "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0"
    threads: config['normalized_coverage']['threads']

    benchmark:
        "benchmarks/normalized_coverage/{sample}.txt"
       
       
       "envs/06_visualization/deeptools.yaml"
       
       
       "[Normalize Coverage] Sample: {wildcards.sample} | Shifted Bam: {input.shifted_bam} | NormalizedCoverage: {output.normalized_coverage} |Method: {params.method}]..."
       
       
    shell: 
         """
         bamCoverage \
             -b {input.shifted_bam} \
             -o {output.normalized_coverage} \
             --normalizeUsing {params.method} \
             --numberOfProcessors {threads} \
             2> {log}
         """

