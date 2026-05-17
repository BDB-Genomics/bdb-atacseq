# ==============================================================================
# Chromatin Velocity - Nucleosome dynamics-based trajectory inference
# ==============================================================================

rule chromatin_velocity:
    input:
        fragments = config.get("chromatin_velocity", {}).get("input", {}).get("fragments", "results/scatac/archr/fragments/fragments.tsv.gz"),
        embedding = config.get("chromatin_velocity", {}).get("input", {}).get("embedding", "results/scatac/archr/plots/umap_coordinates.csv"),
        cell_barcodes = config.get("chromatin_velocity", {}).get("input", {}).get("cell_barcodes", "results/scatac/archr/clusters/cell_barcodes.txt"),
        peaks = config.get("chromatin_velocity", {}).get("input", {}).get("peaks", "results/peak_calling/filtered_peaks/filtered_peaks.bed"),
        cell_annotations = config.get("chromatin_velocity", {}).get("input", {}).get("cell_annotations", "results/scatac/archr/clusters/cell_clusters.tsv"),
    output:
        nfr_ratios = directory(config.get("chromatin_velocity", {}).get("output", {}).get("nfr_ratios", "results/scatac/chromatin_velocity/nfr_ratios")),
        velocity = directory(config.get("chromatin_velocity", {}).get("output", {}).get("velocity", "results/scatac/chromatin_velocity/velocity")),
        plots = directory(config.get("chromatin_velocity", {}).get("output", {}).get("plots", "results/scatac/chromatin_velocity/plots")),
        summary = config.get("chromatin_velocity", {}).get("output", {}).get("summary", "results/scatac/chromatin_velocity/chromatin_velocity_summary.tsv"),
    params:
        n_neighbors = config.get("chromatin_velocity", {}).get("params", {}).get("n_neighbors", 30),
        min_fragments = config.get("chromatin_velocity", {}).get("params", {}).get("min_fragments", 100),
        smoothing_steps = config.get("chromatin_velocity", {}).get("params", {}).get("smoothing_steps", 3),
    threads:
        config.get("chromatin_velocity", {}).get("threads", 8)
    resources:
        mem_mb = config.get("chromatin_velocity", {}).get("resources", {}).get("mem_mb", 16000),
        time = config.get("chromatin_velocity", {}).get("resources", {}).get("time", "02:00:00"),
    conda:
        "rules/envs/chromatin_velocity.yaml"
    shell:
        """
        mkdir -p {output.nfr_ratios} {output.velocity} {output.plots}

        python -m chromatin_velocity.run \
            --fragment-file {input.fragments} \
            --embedding {input.embedding} \
            --cell-barcodes {input.cell_barcodes} \
            --peaks {input.peaks} \
            --cell-annotations {input.cell_annotations} \
            --output-dir {output.velocity} \
            --n-neighbors {params.n_neighbors} \
            --min-fragments {params.min_fragments} \
            --smoothing-steps {params.smoothing_steps}

        cp {output.velocity}/nfr_ratios_per_cell.csv {output.nfr_ratios}/
        cp {output.velocity}/chromatin_velocity_results.csv {output.nfr_ratios}/
        cp {output.velocity}/fragment_size_distribution.csv {output.nfr_ratios}/
        cp {output.velocity}/nucleosome_periodicity.txt {output.nfr_ratios}/

        cp {output.velocity}/velocity_vectors.npy {output.velocity}/
        cp {output.velocity}/transition_probabilities.csv {output.velocity}/

        cp {output.velocity}/*.png {output.plots}/

        echo -e "metric\tvalue" > {output.summary}
        echo -e "n_cells\t$(wc -l < {output.nfr_ratios}/nfr_ratios_per_cell.csv)" >> {output.summary}
        echo -e "mean_nfr_ratio\t$(tail -n +2 {output.nfr_ratios}/nfr_ratios_per_cell.csv | cut -d',' -f5 | awk '{{sum+=$1}} END {{print sum/NR}}')" >> {output.summary}
        """
