rule macs2_peak_calling:
    input:
        shifted_bam=lambda wildcards: f"{config['macs2']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        peaks=f"{config['macs2']['output']['peaks']}/{{sample}}_peaks.narrowPeak"

    params:
        gsize="500000" if IS_CI else config['macs2']['params']['genome_size'],
        qval=config['macs2']['params']['qvalue'],
        nomodel=config['macs2']['params']['nomodel'],
        format=config['macs2']['params']['format'],
        dir=lambda wildcards, output: os.path.dirname(output.peaks)

    resources:
        mem_mb=config['macs2']['resources']['mem_mb'],
        time=config['macs2']['resources']['time']

    log: "logs/macs2/{sample}.err"
    benchmark: "benchmarks/macs2/{sample}.txt"
    conda: "envs/05_peak_calling/macs2.yaml"
    container: "https://depot.galaxyproject.org/singularity/macs2:2.2.7.1--py38h4a9c2d4_3"
    threads: config['macs2']['threads']
    message: "[MACS2 PEAKCALLING] SAMPLE:  {wildcards.sample} | Shifted_Bam: {input.shifted_bam} | Peaks: {output.peaks} | Genome Size: {params.gsize} | QVal: {params.qval} | Nomodel: {params.nomodel} | Model: {params.format}]"

    shell:
        """
        macs2 callpeak \
            -t {input.shifted_bam} \
            -f {params.format} \
            -g {params.gsize} \
            -n {wildcards.sample} \
            --outdir {params.dir} \
            {params.nomodel} \
            -q {params.qval} \
            2> {log}

         """
