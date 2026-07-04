rule preseq:
    input:
        bam=lambda wildcards: f"{config['preseq']['input']['noMT_sorted_bam']}/{wildcards.sample}_noMT.sorted.bam"
         
    output:
        complexity=f"{config['preseq']['output']['predicted_complexity']}/{{sample}}.ccurve.txt"
        
    params:
        extra="lc_extrap",  #"lc_extrap" to predict library complexity

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['preseq']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['preseq']['resources']['time'] * attempt,
        
    log: "logs/preseq/{sample}.err"
    benchmark: "benchmarks/preseq/{sample}.txt"
    conda: "envs/04_metrics_qc/preseq.yaml"
    container: "https://depot.galaxyproject.org/singularity/preseq:3.2.0--h0f4d3ed_3"
    threads: config['preseq'].get('threads', 1)
    message: "[Preseq Sample: {wildcards.sample} | Bam: {input.bam} | Complexity: {output.complexity} | Extra: {params.extra} ]"
    
    shell:
        """
        preseq {params.extra} \
            -B {input.bam} \
            -o {output.complexity} \
            2> {log}
        """

