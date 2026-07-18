rule footprinting:
    input:
        bam=lambda wildcards: f"{config['footprinting']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam",
        peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"

    output:
        footprints=f"{config['footprinting']['output']['footprints']}/{{sample}}_footprints.bed"

    params:
        organism=config['footprinting']['params']['organism'],
        genome_fa=lambda wildcards: f"{__import__('pathlib').Path(config['global']['references']['genome_fa']).resolve()}",
        rgt_genome_dir=lambda wildcards: f"{__import__('os').path.expanduser('~')}/rgtdata/{config['footprinting']['params']['organism']}",
        tmp_dir=lambda wildcards, output: f"{__import__('os').path.dirname(output.footprints)}/tmp_{wildcards.sample}"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['footprinting']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['footprinting']['resources']['time'] * attempt,

    log: "logs/footprinting/{sample}.err"
    benchmark: "benchmarks/footprinting/{sample}.txt"
    conda: "envs/05_peak_calling/footprinting.yaml"
    container: "docker://quay.io/biocontainers/rgt:0.13.2--py39h1f90b4d_0"
    threads: config['footprinting']['threads']
    message: "[Footprinting] {wildcards.sample} | organism: {params.organism}"

    shell:
        """
        if [ ! -s {input.peaks} ] || [ $(wc -l < {input.peaks}) -eq 0 ]; then
            echo "Peak file {input.peaks} is empty. Cannot perform footprinting." >> {log}
            exit 1
        else
            mkdir -p {params.rgt_genome_dir}
            cp -f {params.genome_fa} {params.rgt_genome_dir}/genome_{params.organism}.fa
            mkdir -p {params.tmp_dir}
            if rgt-hint footprinting \
                --atac-seq \
                --paired-end \
                --organism={params.organism} \
                --output-location={params.tmp_dir} \
                --output-prefix={wildcards.sample} \
                {input.bam} \
                {input.peaks} \
                2>> {log}; then
                if [ -f {params.tmp_dir}/{wildcards.sample}.bed ]; then
                    mv {params.tmp_dir}/{wildcards.sample}.bed {output.footprints}
                else
                    echo "[ERROR] rgt-hint completed but output file not found." >> {log}
                    exit 1
                fi
            else
                echo "[ERROR] rgt-hint footprinting failed." >> {log}
                exit 1
            fi
            rm -rf {params.tmp_dir}
        fi
        echo "Footprinting complete for {wildcards.sample}" >> {log}
        """
