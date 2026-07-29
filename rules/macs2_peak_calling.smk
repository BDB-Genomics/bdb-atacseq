rule macs2_peak_calling:
    input:
        shifted_bam=lambda wildcards: f"{config['macs2']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        peaks=f"{config['macs2']['output']['peaks']}/{{sample}}_peaks.narrowPeak"

    params:
        gsize=sum(int(line.strip().split()[1]) for line in open(config['global']['references']['genome_sizes'])),
        qval=config['macs2']['params']['qvalue'],
        nomodel=config['macs2']['params']['nomodel'],
        format=config['macs2']['params']['format'],
        bootstrap_dir=".snakemake/macs2_source",
        site_dir=".snakemake/macs2_source/site",
        sentinel=".snakemake/macs2_source/.installed",
        dir=lambda wildcards, output: __import__('os').path.dirname(output.peaks)

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['macs2']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['macs2']['resources']['time'] * attempt,

    log: "logs/macs2/{sample}.err"
    benchmark: "benchmarks/macs2/{sample}.txt"
    conda: "envs/05_peak_calling/macs2.yaml" if config.get("use_conda", True) else None
    # Use the conda environment instead of the container image because the
    # containerized MACS2 wheel has been failing in CI with a missing libm
    # symbol during import.
    container: "docker://quay.io/biocontainers/macs2:2.2.9.1--py311haab0aaa_5" if config.get("use_container", True) else None
    threads: config['macs2']['threads']
    message: "[MACS2 PEAKCALLING] SAMPLE:  {wildcards.sample} | Shifted_Bam: {input.shifted_bam} | Peaks: {output.peaks} | Genome Size: {params.gsize} | QVal: {params.qval} | Nomodel: {params.nomodel} | Model: {params.format}]"

    script: "scripts/macs2_peak_calling.py"
