rule chromvar_analysis:
    input:
        shifted_bam=lambda wildcards: f"{config['chromvar_analysis']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        motif_db=config['chromvar_analysis']['params']['motif_db']

    output:
        deviations=f"{config['chromvar_analysis']['output']['deviations']}/{{sample}}_deviations.tsv",
        bias_corrected=f"{config['chromvar_analysis']['output']['bias_corrected']}/{{sample}}_bias_corrected.tsv",
        plot=f"{config['chromvar_analysis']['output']['plots']}/{{sample}}_chromvar_plot.pdf"

    params:
        genome=config['chromvar_analysis']['params']['genome_fa'],
        genome_sizes=config['chromvar_analysis']['params']['genome_sizes']

    resources:
        mem_mb=config['chromvar_analysis']['resources']['mem_mb'],
        time=config['chromvar_analysis']['resources']['time']

    log: "logs/chromvar/{sample}.err"
    benchmark: "benchmarks/chromvar/{sample}.txt"
    conda: "envs/05_peak_calling/chromvar.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-chromvar:1.28.0--r42hdfd78af_0"
    threads: config['chromvar_analysis']['threads']
    message: "[chromVAR] Sample: {wildcards.sample} | BAM: {input.shifted_bam} | Peaks: {input.peaks} | Motifs: {input.motif_db}"

    script:
        "rules/scripts/chromvar_analysis.R"
