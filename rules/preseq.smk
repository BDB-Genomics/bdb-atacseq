rule preseq:
    input:
        markdup_bam_index=lambda wildcards: f"{config['preseq']['input']['markdup_bam_index']}/{wildcards.sample}_noMT.sorted.dedup.bam.bai",
        markdup_bam=lambda wildcards: f"{config['preseq']['input']['markdup_bam']}/{wildcards.sample}_noMT.sorted.dedup.bam"
         
    output:
        complexity=f"{config['preseq']['output']['predicted_complexity']}/{{sample}}.ccurve.txt"
        
    params:
        extra="lc_extrap",  #"lc_extrap" to predict library complexity

    resources:
        mem_mb=config['preseq']['resources']['mem_mb'], 
        time=config['preseq']['resources']['time']
        
    benchmark:
        "benchmarks/preseq/{sample}.txt"
    
    log:
        "logs/preseq/{sample}.err"
  
    conda:
        "envs/04_metrics_qc/preseq.yaml"

    message:
        "[Preseq Sample: {wildcards.sample} | Markedup Bam Index: {input.markdup_bam_index} , Markedup Bam: {input.markdup_bam} | Complexity: {output.complexity} | Extra: {params.extra} ]"
        
    shell:
        """
        preseq {params.extra} \
            -B {input.markdup_bam} \
            -o {output.complexity} \
            2> {log} || (echo "Preseq failed on {wildcards.sample}." >> {log}; true)
        """

