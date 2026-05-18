rule idr_analysis:
    input:
        rep1=lambda wildcards: f"{config['macs2']['output']['peaks']}/{COND_REP_TO_SAMPLE[(wildcards.condition, wildcards.rep1)]}_peaks.narrowPeak",
        rep2=lambda wildcards: f"{config['macs2']['output']['peaks']}/{COND_REP_TO_SAMPLE[(wildcards.condition, wildcards.rep2)]}_peaks.narrowPeak"

    output:
        idr_peaks=f"{config['idr']['output']['idr_peaks']}/{{condition}}_rep{{rep1}}_rep{{rep2}}_idr_peaks.bed",
        opt_peaks=f"{config['idr']['output']['optimal_peaks']}/{{condition}}_rep{{rep1}}_rep{{rep2}}_optimal_peaks.bed",
        plot=f"{config['idr']['output']['plots']}/{{condition}}_rep{{rep1}}_rep{{rep2}}_idr_plot.png"

    params:
        idr_threshold=config['idr']['params']['idr_threshold'],
        rank=config['idr']['params']['rank_column']

    resources:
        mem_mb=config['idr']['resources']['mem_mb'],
        time=config['idr']['resources']['time']

    log: "logs/idr/{condition}_rep{rep1}_rep{rep2}.err"
    benchmark: "benchmarks/idr/{condition}_rep{rep1}_rep{rep2}.txt"
    conda: "envs/05_peak_calling/idr.yaml"
    container: "https://depot.galaxyproject.org/singularity/idr:2.0.4.3--pyh5e36f6f_0"
    threads: config['idr']['threads']
    message: "[IDR] Condition: {wildcards.condition} | Reps: {wildcards.rep1},{wildcards.rep2} | Output: {output.idr_peaks}"

    shell:
        """
        idr \
            --samples {input.rep1} {input.rep2} \
            --input-file-type narrowPeak \
            --rank {params.rank} \
            --output-file {output.idr_peaks} \
            --idr-threshold {params.idr_threshold} \
            --plot \
            --log-output-file {log} 2>&1 | tee -a {log}

        IDR_PREFIX="{output.idr_peaks}"
        IDR_PREFIX="${{IDR_PREFIX%.bed}}"
        mv ${{IDR_PREFIX}}_*-plot.png {output.plot} 2>/dev/null || true
        cp ${{IDR_PREFIX}}_optimal* {output.opt_peaks} 2>/dev/null || true
        """
