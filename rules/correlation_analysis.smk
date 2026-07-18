rule correlation_analysis: 
    input: 
        bigwig=expand("{path}/{sample}.bw", path=config['correlation_analysis']['input']['bigwig'], sample=SAMPLES)
        
    output: 
         npz=f"{config['correlation_analysis']['output']}/matrix.npz", 
         tab=f"{config['correlation_analysis']['output']}/matrix.tab", 
         heatmap=f"{config['correlation_analysis']['output']}/correlation_heatmap.png",
         cor_matrix=f"{config['correlation_analysis']['output']}/correlation_values.tab"
         
    params:
        bin_size=config['correlation_analysis']['params']['bin_size']
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['correlation_analysis']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['correlation_analysis']['resources']['time'] * attempt,

    log: "logs/correlation_analysis/correlation_analysis.err"
    benchmark: "benchmarks/correlation_analysis/correlation_analysis.txt"
    conda: "envs/06_visualization/deeptools.yaml"
    container: "docker://quay.io/biocontainers/deeptools:3.5.1--py_0"
    threads: config['correlation_analysis']['threads']
    message: "[multiBigwigSummary +  plotCorrelation] | BigWigs: {input.bigwig} | Outputs: {output.npz}, {output.tab}, {output.heatmap} | Binsize: {params.bin_size} ..."
                
    shell: 
        """
        multiBigwigSummary bins \
            --bwfiles {input.bigwig} \
            --binSize {params.bin_size} \
            --numberOfProcessors {threads} \
            --outFile {output.npz} \
            --outRawCounts {output.tab} \
            2> {log} && \
             
        plotCorrelation \
            --corData {output.npz} \
            --corMethod pearson \
            --whatToPlot heatmap \
            --plotNumbers \
            --outFileCorMatrix {output.cor_matrix} \
            --plotFile {output.heatmap} \
            --removeOutliers \
            --skipZeros \
            2>> {log}
   
        """
