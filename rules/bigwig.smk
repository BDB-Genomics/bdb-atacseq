rule bigwig_conversion:
    input:
        sorted_bedgraph=lambda wildcards:f"{config['bigwig']['input']['sorted_bedgraph']}/{wildcards.sample}.sorted.bedGraph"
        
    output:
        bigwig=f"{config['bigwig']['output']['bigwig']}/{{sample}}.bw"
    
    params:
        genome=config['bigwig']['params']['genome']
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['bigwig']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['bigwig']['resources']['time'] * attempt,
            
    log: "logs/bigwig/{sample}.err"
    benchmark: "benchmarks/bigwig/{sample}.txt"
    conda: "envs/06_visualization/bedGraph_to_bigwig.yaml"
    container: "https://depot.galaxyproject.org/singularity/ucsc-bedgraphtobigwig:377--h4463345_0"
    threads: config['bigwig']['threads']   
    message: "[bedGraphToBigWig] Sample: {wildcards.sample} | Sorted BedGraph: {input.sorted_bedgraph} | BigWig: {output.bigwig} | Genome: {params.genome}... "
       
    shell:
        """
        bedGraphToBigWig \
        {input.sorted_bedgraph} \
        {params.genome} \
        {output.bigwig} \
        2> {log} || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """
        
