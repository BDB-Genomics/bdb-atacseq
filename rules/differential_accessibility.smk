rule differential_accessibility:
    input:
        counts=expand("{path}/{sample}_peak_counts.tsv", path=config['count_peaks']['output'], sample=SAMPLES),
        sample_sheet=config['global']['samples'],
        qc_pass=expand("{path}/{sample}_qc_pass.txt", path=config['qc_gate']['output'], sample=SAMPLES)

    output:
        results=f"{config['differential_accessibility']['output']['results']}/diff_accessibility_results.tsv",
        plot_volcano=f"{config['differential_accessibility']['output']['plots']}/volcano_plot.pdf",
        plot_ma=f"{config['differential_accessibility']['output']['plots']}/ma_plot.pdf",
        plot_heatmap=f"{config['differential_accessibility']['output']['plots']}/heatmap.pdf",
        plot_pca=f"{config['differential_accessibility']['output']['plots']}/pca_plot.pdf"

    params:
        fdr_threshold=config['differential_accessibility']['params']['fdr_threshold'],
        log2fc_threshold=config['differential_accessibility']['params']['log2fc_threshold'],
        n_counts=lambda wildcards, input: len(input.counts)

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['differential_accessibility']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['differential_accessibility']['resources']['time'] * attempt,

    log: "logs/differential_accessibility/diff.err"
    benchmark: "benchmarks/differential_accessibility/diff.txt"
    conda: "envs/05_peak_calling/diff_accessibility.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-deseq2:1.40.2--r42hdfd78af_0"
    threads: config['differential_accessibility']['threads']
    message: "[Differential Accessibility] Running DESeq2 on {params.n_counts} samples"

    script:
        "scripts/diff_accessibility.R"
