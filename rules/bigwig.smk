rule bigwig_conversion:
    input:
        sorted_bedgraph=lambda wildcards:f"{config['bigwig']['input']['sorted_bedgraph']}/{wildcards.sample}.sorted.bedGraph"
        
    output:
        bigwig=f"{config['bigwig']['output']['bigwig']}/{{sample}}.bw"

    resources:
        mem_mb=config['bigwig']['resources']['mem_mb'], 
        time=config['bigwig']['resources']['time']
            

    log: "logs/bigwig/{sample}.err" 
    conda: "envs/06_visualization/bedGraph_to_bigwig.yaml" 
    threads: config['bigwig']['threads'] 

    params:
        genome=config['bigwig']['params']['genome']
        
    benchmark:
        "benchmarks/bigwig/{sample}.txt"
        
       "[bedGraphToBigWig] Sample: {wildcards.sample} | Sorted BedGraph: {input.sorted_bedgraph} | BigWig: {output.bigwig} | Genome: {params.genome}... "
       
    shell:
        """
        bedGraphToBigWig \
        {input.sorted_bedgraph} \
        {params.genome} \
        {output.bigwig} \
        2> {log} 
        """
        
