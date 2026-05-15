rule heatmap:
    input:
        filtered_peaks=lambda wildcards: f"{config['heatmap']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        bigwig=lambda wildcards: f"{config['heatmap']['input']['bigwig']}/{wildcards.sample}.bw"
        
    output:
        matrix=f"{config['heatmap']['output']['matrix']}/{{sample}}_matrix.gz", 
        regions=f"{config['heatmap']['output']['regions']}/{{sample}}_regions.bed", 
        plot=f"{config['heatmap']['output']['plot']}/{{sample}}_tss_heatmap.pdf"
        
    params:
        upstream=config['heatmap']['params'].get('upstream', 3000),
        downstream=config['heatmap']['params'].get('downstream', 3000), 
        colormap=config['heatmap']['params'].get("color", "coolwarm")

    resources:
        mem_mb=config['heatmap']['resources']['mem_mb'], 
        time=config['heatmap']['resources']['time']
        

    log: matrix="logs/heatmap/matrix/{sample}.err", plot="logs/heatmap/plot/{sample}.err" 
    conda: "envs/06_visualization/deeptools.yaml" 
    threads: config['heatmap']['threads'] 
    message: "[deepTools heatmap] Sample: {wildcards.sample} | BigWig: {input.bigwig} | Peaks: {input.filtered_peaks} | Output: {output.plot}" 

    benchmark:
        "benchmarks/heatmap/{sample}.txt"
        
    shell:
        """
        computeMatrix reference-point \
            --referencePoint TSS \
            -b {params.upstream} -a {params.downstream} \
            -R {input.filtered_peaks} \
            -S {input.bigwig} \
            --skipZeros \
            --missingDataAsZero \
            --numberOfProcessors {threads} \
            -out {output.matrix} \
            --outFileSortedRegions {output.regions} \
            2> {log.matrix}

        plotHeatmap \
            -m {output.matrix} \
            -out {output.plot} \
            --colorMap {params.colormap} \
            --regionsLabel "TSS" \
            --samplesLabel {wildcards.sample} \
            --heatmapHeight 12 --heatmapWidth 6 \
            2>> {log.plot}
        """

