rule samtools_fixmate:
    input:
        sorted_bam_noMT = lambda wildcards: f"{config['samtools_fixmate']['input']['sorted_bam_noMT']}/{wildcards.sample}.sorted.bam"
    
    output:
        sorted_bam_noMT_fixmate = f"{config['samtools_fixmate']['output']['sorted_bam_noMT_fixmate']}/{{sample}}.sorted.fixmate.bam"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config["samtools_fixmate"]['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config["samtools_fixmate"]['resources']['time'] * attempt,

    log: "logs/samtools_fixmate/{sample}.err"
    benchmark: "benchmarks/samtools_fixmate/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "docker://quay.io/biocontainers/samtools:1.15.1--h1170115_0"
    threads: config["samtools_fixmate"]["threads"]
    message: "[SAMTOOLS FIXMATE] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT}| OUTPUT: {output.sorted_bam_noMT_fixmate}"
 
    shell:
        """
        set -o pipefail
        samtools sort -n -@ {threads} {input.sorted_bam_noMT} |  samtools fixmate -m -@ {threads} - - | samtools sort -@ {threads} -o {output.sorted_bam_noMT_fixmate} - 2> {log}
       """
       
