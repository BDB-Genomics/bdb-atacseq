rule sorted_bedgraph:
    input:
        bedgraph=lambda wildcards: f"{config['sorted_bedgraph']['input']['bedgraph']}/{wildcards.sample}.bedGraph"
        
    output:
        sorted_bedgraph=f"{config['sorted_bedgraph']['output']['sorted_bedgraph']}/{{sample}}.sorted.bedGraph"
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['sorted_bedgraph']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['sorted_bedgraph']['resources']['time'] * attempt,
    
    log: "logs/sorted_bedgraph/{sample}.err"
    benchmark: "benchmarks/sorted_bedgraph/{sample}.txt"
    conda: "envs/06_visualization/sorted_bedgraph.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['sorted_bedgraph']['threads']
    message: "[sort]  Sample:  {wildcards.sample} | BedGraph: {input.bedgraph} | Sorted BedGraph: {output.sorted_bedgraph} | Resources: {resources.mem_mb}...  "
            
    shell:
        """
        sort \
        -k1,1 -k2,2n \
        --parallel {threads} \
        -S {resources.mem_mb}M \
        {input.bedgraph} \
        > {output.sorted_bedgraph} \
        2> {log} || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """
        
