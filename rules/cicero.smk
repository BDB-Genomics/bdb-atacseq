rule cicero_coaccessibility:
    input:
        arrow_dir=config['archr']['output']['filtered_arrow'],
        clusters=f"{config['archr']['output']['clusters']}/cell_clusters.tsv",
        genome_sizes=config['global']['references']['genome_sizes']

    output:
        conn_net=f"{config['cicero']['output']['connections']}/coaccessibility_connections.rds",
        conn_df=f"{config['cicero']['output']['connections']}/coaccessibility_table.tsv",
        ccans_net=f"{config['cicero']['output']['ccans']}/ccans.rds",
        ccans_bed=f"{config['cicero']['output']['ccans']}/ccans.bed",
        plot=f"{config['cicero']['output']['plots']}/coaccessibility_plot.png"

    params:
        window_size=config['cicero']['params']['window_size'],
        distance_cutoff=config['cicero']['params']['distance_cutoff']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['cicero']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['cicero']['resources']['time'] * attempt,

    log: "logs/cicero/coaccessibility.err"
    benchmark: "benchmarks/cicero/coaccessibility.txt"
    conda: "envs/scatac/cicero.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-cicero:1.20.0--r43hdfd78af_0"
    threads: config['cicero']['threads']
    message: "[Cicero] Computing chromatin co-accessibility networks"

    script:
        "scripts/cicero_analysis.R"
