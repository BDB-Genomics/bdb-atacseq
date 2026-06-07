import os
rule footprinting:
    input:
        bam=lambda wildcards: f"{config['footprinting']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"

    output:
        footprints=f"{config['footprinting']['output']['footprints']}/{{sample}}_footprints.bed"

    params:
        organism=config['footprinting']['params']['organism'],
        tmp_dir=lambda wildcards, output: f"{os.path.dirname(output.footprints)}/tmp_{wildcards.sample}"

    resources:
        mem_mb=config['footprinting']['resources']['mem_mb'],
        time=config['footprinting']['resources']['time']

    log: "logs/footprinting/{sample}.err"
    benchmark: "benchmarks/footprinting/{sample}.txt"
    conda: "envs/05_peak_calling/footprinting.yaml"
    container: "https://depot.galaxyproject.org/singularity/rgt:0.13.2--py39h1f90b4d_0"
    threads: config['footprinting']['threads']
    message: "[Footprinting] {wildcards.sample} | organism: {params.organism}"

    shell:
        """
        mkdir -p {params.tmp_dir}

        # In a container rgt-data may not be pre-initialized.
        # Attempt setup; if it fails (no network / read-only FS), fall back to
        # --bias-correction which skips the genome registry entirely.
        if rgt-data --setup 2>> {log}; then
            BIAS_FLAG=""
        else
            echo "rgt-data setup failed; using --bias-correction to skip genome registry" >> {log}
            BIAS_FLAG="--bias-correction"
        fi

        rgt-hint footprinting \
            --atac-seq \
            --paired-end \
            --organism={params.organism} \
            $BIAS_FLAG \
            --output-location={params.tmp_dir} \
            --output-prefix={wildcards.sample} \
            {input.bam} \
            {input.peaks} \
            2>> {log}

        mv {params.tmp_dir}/{wildcards.sample}.bed {output.footprints}
        rm -rf {params.tmp_dir}

        echo "Footprinting complete for {wildcards.sample}" >> {log}
        """
