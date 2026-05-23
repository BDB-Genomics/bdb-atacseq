rule cross_correlation:
    input:
        shifted_bam=lambda wildcards: f"{config['cross_correlation']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        stats=f"{config['cross_correlation']['output']}/{{sample}}_crosscorr.txt",
        plot=f"{config['cross_correlation']['output']}/{{sample}}_crosscorr.pdf"

    params:
        num_threads=config['cross_correlation']['params']['num_threads'],
        max_range=config['cross_correlation']['params']['max_range']

    resources:
        mem_mb=config['cross_correlation']['resources']['mem_mb'],
        time=config['cross_correlation']['resources']['time']

    log: "logs/cross_correlation/{sample}.err"
    benchmark: "benchmarks/cross_correlation/{sample}.txt"
    conda: "envs/04_metrics_qc/cross_correlation.yaml"
    container: "https://depot.galaxyproject.org/singularity/phantompeakqualtools:1.2.2--r42hdfd78af_0"
    threads: config['cross_correlation']['threads']
    message: "[Cross-Correlation] Sample: {wildcards.sample} | BAM: {input.shifted_bam} | Output: {output.stats}"

    shell:
        """
        Rscript $(which run_spp.R) \
            -c={input.shifted_bam} \
            -savp={output.plot} \
            -out={output.stats} \
            -rf \
            -p={params.num_threads} \
            -s=10:5:{params.max_range} \
            2> {log}
        """
