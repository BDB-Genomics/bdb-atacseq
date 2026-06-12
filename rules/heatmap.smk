rule heatmap:
    input:
        filtered_peaks=lambda wildcards: f"{config['heatmap']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        bigwig=lambda wildcards: f"{config['heatmap']['input']['bigwig']}/{wildcards.sample}.bw",
        qc_pass=lambda wildcards: f"{config['qc_gate']['output']}/{wildcards.sample}_qc_pass.txt"

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
    benchmark: "benchmarks/heatmap/{sample}.txt"
    conda: "envs/06_visualization/deeptools.yaml"
    container: "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0"
    threads: config['heatmap']['threads']
    message: "[deepTools heatmap] Sample: {wildcards.sample} | BigWig: {input.bigwig} | Peaks: {input.filtered_peaks} | Output: {output.plot}"

    shell:
        """
        mkdir -p $(dirname {output.plot})
        mkdir -p $(dirname {output.matrix})
        mkdir -p $(dirname {output.regions})

        if [ ! -s {input.filtered_peaks} ] || [ $(wc -l < {input.filtered_peaks}) -eq 0 ]; then
            echo "[WARNING] Peak file is empty. Generating dummy heatmap outputs." > {log.matrix}
            python3 -c "import gzip, os; os.makedirs(os.path.dirname('{output.matrix}'), exist_ok=True); gzip.open('{output.matrix}', 'wb').write(b'# computeMatrix dummy')"
            python3 -c "import os; os.makedirs(os.path.dirname('{output.regions}'), exist_ok=True); open('{output.regions}', 'w').write('')"
            python3 -c "import os, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt; os.makedirs(os.path.dirname('{output.plot}'), exist_ok=True); fig, ax = plt.subplots(); ax.text(0.5, 0.5, 'No peaks found for heatmap', size=15, ha='center', va='center'); plt.savefig('{output.plot}')" 2> {log.plot}
        else
            computeMatrix reference-point \
                --referencePoint center \
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
                --regionsLabel "Peak Centers" \
                --samplesLabel {wildcards.sample} \
                --heatmapHeight 12 --heatmapWidth 6 \
                2>> {log.plot}
        fi
        """
