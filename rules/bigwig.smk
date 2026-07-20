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
    conda: "envs/06_visualization/bedGraph_to_bigwig.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/ucsc-bedgraphtobigwig:445--h954228d_0" if config.get("use_container", True) else None
    threads: config['bigwig']['threads']   
    message: "[bedGraphToBigWig] Sample: {wildcards.sample} | Sorted BedGraph: {input.sorted_bedgraph} | BigWig: {output.bigwig} | Genome: {params.genome}... "
       
    shell:
        """
        if [ ! -s {input.sorted_bedgraph} ]; then
            echo "Input sorted_bedgraph is empty. Generating empty/placeholder BigWig." > {log}
            touch {output.bigwig}
        else
            bedGraphToBigWig \
            {input.sorted_bedgraph} \
            {params.genome} \
            {output.bigwig} \
            2> {log}
        fi
        """
        
