rule archr_pseudobulk:
    input:
        bam=expand("{path}/{sample}_tag.bam", path=config['chromap']['output'], sample=SAMPLES),
        sample_sheet=config['global']['samples']

    output:
        arrow_dir=directory(config['archr']['output']['arrow'])

    params:
        min_tss=config['archr']['params']['min_tss'],
        min_frags=config['archr']['params']['min_frags'],
        max_frags=config['archr']['params']['max_frags'],
        tsse_method=config['archr']['params']['tsse_method']

    resources:
        mem_mb=config['archr']['resources']['mem_mb'],
        time=config['archr']['resources']['time']

    log: "logs/archr/pseudobulk.err"
    benchmark: "benchmarks/archr/pseudobulk.txt"
    conda: "envs/scatac/archr.yaml"
    container: "https://depot.galaxyproject.org/singularity/r-base:4.3"
    threads: config['archr']['threads']
    message: "[ArchR Pseudo-bulk] Creating Arrow files from scATAC-seq BAMs"

    script:
        "rules/scripts/archr_pseudobulk.R"

rule archr_doublet_detection:
    input:
        arrow_dir=directory(config['archr']['output']['arrow'])

    output:
        doublet_report=f"{config['archr']['output']['doublets']}/doublet_enrichment.pdf",
        filtered_arrow_dir=directory(config['archr']['output']['filtered_arrow'])

    params:
        doublet_threshold=config['archr']['params']['doublet_threshold']

    resources:
        mem_mb=config['archr']['resources']['mem_mb'],
        time=config['archr']['resources']['time']

    log: "logs/archr/doublets.err"
    benchmark: "benchmarks/archr/doublets.txt"
    conda: "envs/scatac/archr.yaml"
    threads: config['archr']['threads']
    message: "[ArchR Doublet Detection] Removing doublets from scATAC-seq data"

    script:
        "rules/scripts/archr_doublets.R"

rule archr_clustering:
    input:
        arrow_dir=directory(config['archr']['output']['filtered_arrow'])

    output:
        clusters=f"{config['archr']['output']['clusters']}/cell_clusters.tsv",
        umap=f"{config['archr']['output']['plots']}/umap_clusters.pdf",
        marker_genes=f"{config['archr']['output']['markers']}/marker_genes.tsv",
        full_report=f"{config['archr']['output']['qc_report']}/ArchR_full_report.pdf"

    params:
        resolution=config['archr']['params']['clustering_resolution'],
        dims_to_use=config['archr']['params']['dims_to_use'],
        force_dim_reduction=config['archr']['params']['force_dim_reduction']

    resources:
        mem_mb=config['archr']['resources']['mem_mb'],
        time=config['archr']['resources']['time']

    log: "logs/archr/clustering.err"
    benchmark: "benchmarks/archr/clustering.txt"
    conda: "envs/scatac/archr.yaml"
    threads: config['archr']['threads']
    message: "[ArchR Clustering] Identifying cell types from scATAC-seq data"

    script:
        "rules/scripts/archr_clustering.R"
