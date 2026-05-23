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
        mem_mb=config['cicero']['resources']['mem_mb'],
        time=config['cicero']['resources']['time']

    log: "logs/cicero/coaccessibility.err"
    benchmark: "benchmarks/cicero/coaccessibility.txt"
    conda: "envs/scatac/cicero.yaml"
    container: "https://depot.galaxyproject.org/singularity/r-base:4.3"
    threads: config['cicero']['threads']
    message: "[Cicero] Computing chromatin co-accessibility networks"

    script:
        os.path.abspath("rules/scripts/cicero_analysis.R")
