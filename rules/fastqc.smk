rule fastqc:
    input: 
        R1_trimmed=lambda wildcards: f"{config['fastqc']['input']['R1']}/{wildcards.sample}_R1_trimmed.fastq.gz",
        R2_trimmed=lambda wildcards: f"{config['fastqc']['input']['R2']}/{wildcards.sample}_R2_trimmed.fastq.gz"
    
    output:
        R1_report = f"{config['fastqc']['output']}/{{sample}}_R1_trimmed_fastqc.html",
        R1_zip = f"{config['fastqc']['output']}/{{sample}}_R1_trimmed_fastqc.zip",
        R2_report = f"{config['fastqc']['output']}/{{sample}}_R2_trimmed_fastqc.html",
        R2_zip = f"{config['fastqc']['output']}/{{sample}}_R2_trimmed_fastqc.zip"
    
    params:
        out_dir=lambda wildcards, output: __import__('os').path.dirname(output.R1_report)
        
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['fastqc']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['fastqc']['resources']['time'] * attempt,
                            
    log: "logs/fastqc/{sample}.err"
    benchmark: "benchmarks/fastqc/{sample}.txt"
    conda: "envs/01_preprocessing/fastqc.yaml"
    container: "https://depot.galaxyproject.org/singularity/fastqc:0.11.9--0"
    threads: config["fastqc"]["threads"]
    message: "[FASTQC] SAMPLES: {wildcards.sample}|INPUT: {input.R1_trimmed} {input.R2_trimmed}|OUTPUT: {output.R1_report} {output.R1_zip} {output.R2_report} {output.R2_zip}|DIRECTORY: {params.out_dir}"
               
    shell:
        """
        fastqc \
        -t {threads} \
        -o {params.out_dir} \
        {input.R1_trimmed} {input.R2_trimmed} \
        2> {log}
        """
