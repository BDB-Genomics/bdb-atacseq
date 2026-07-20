rule bedtools_genomecov:
    input:
        shifted_bam=lambda wildcards: f"{config['bedtools_genomecov']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam",
        qc_pass=lambda wildcards: f"{config['qc_gate']['output']}/{wildcards.sample}_qc_pass.txt" if MODE == "bulk" else []

    output:
        bedgraph=f"{config['bedtools_genomecov']['output']['bedgraph']}/{{sample}}.bedGraph"

    params:
        extra=config['bedtools_genomecov']['params']['extra']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['bedtools_genomecov']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['bedtools_genomecov']['resources']['time'] * attempt,

    log: "logs/bedtools_genomecov/{sample}.err"
    benchmark: "benchmarks/bedtools_genomecov/{sample}.txt"
    conda: "envs/03_post_alignment/bedtools.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/bedtools:2.30.0--h468198e_3" if config.get("use_container", True) else None
    threads: config['bedtools_genomecov']['threads']
    message: "[bedtools genomecov] sample: {wildcards.sample} | BAM : {input.shifted_bam}| Output: {output.bedgraph}..."

    shell:
        """
        if [ -n "{input.qc_pass}" ]; then
            status=$(awk '{{print $2}}' {input.qc_pass})
        else
            status="PASSED"
        fi

        if [ "$status" = "PASSED" ]; then
            bedtools genomecov \
              -ibam {input.shifted_bam} \
              {params.extra} \
              > {output.bedgraph} \
              2> {log}
        else
            echo "QC FAILED for {wildcards.sample}. Generating placeholder files." > {log}
            touch {output.bedgraph}
        fi
        """
