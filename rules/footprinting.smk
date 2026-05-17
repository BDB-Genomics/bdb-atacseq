rule footprinting:
    input:
        shifted_bam=lambda wildcards: f"{config['footprinting']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"

    output:
        footprints=f"{config['footprinting']['output']['footprints']}/{{sample}}_footprints.bed",
        regions=f"{config['footprinting']['output']['regions']}/{{sample}}_footprint_regions.bed"

    params:
        genome=config['footprinting']['params']['genome_fa'],
        method=config['footprinting']['params']['method'],
        tmp_dir=lambda wildcards, output: f"{os.path.dirname(output.footprints)}/tmp_{wildcards.sample}"

    resources:
        mem_mb=config['footprinting']['resources']['mem_mb'],
        time=config['footprinting']['resources']['time']

    log: "logs/footprinting/{sample}.err"
    benchmark: "benchmarks/footprinting/{sample}.txt"
    conda: "envs/05_peak_calling/footprinting.yaml"
    container: "https://depot.galaxyproject.org/singularity/hint:0.10.0--py38hdfd78af_0"
    threads: config['footprinting']['threads']
    message: "[Footprinting] Sample: {wildcards.sample} | BAM: {input.shifted_bam} | Peaks: {input.peaks} | Method: {params.method}"

    shell:
        """
        if [ "{params.method}" = "HINT-ATAC" ]; then
            hint-atac \
                --bamfile {input.shifted_bam} \
                --bedfile {input.peaks} \
                --reference {params.genome} \
                --outdir {params.tmp_dir} \
                --ncpus {threads} \
                2> {log}

            cp {params.tmp_dir}/footprints.bed {output.footprints}
            cp {params.tmp_dir}/regions.bed {output.regions}
            rm -rf {params.tmp_dir}
        fi

        echo "Footprinting complete for {wildcards.sample}" >> {log}
        """
