# [TEMPLATE] Name your rule here.
rule template_tool:
    # [TEMPLATE] Define inputs by pointing to the config file path dynamically.
    input:
        dummy_in=lambda wildcards: f"{config['template_category']['template_tool']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz"
    
    # [TEMPLATE] Define outputs using wildcards (like {sample}) so Snakemake can parallelize.
    output:
        dummy_out=f"{config['template_category']['template_tool']['output']}/{{sample}}_template.txt"
    
    # [TEMPLATE] Pull custom parameters from the config file.
    params:
        message=config['template_category']['template_tool']['params']['message']
    
    # [TEMPLATE] Link threads and resources to ensure the scheduler allocates properly.
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['template_category']['template_tool']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['template_category']['template_tool']['resources']['time'] * attempt,
    

    log: "logs/template_category/template_tool/{sample}.log"
    conda: "envs/misc/template_tool.yaml"
    container: "https://depot.galaxyproject.org/singularity/python:3.10.4"
    threads: config['template_category']['template_tool']['threads']

    # [TEMPLATE] Specify where logs and benchmarks will be saved.
    benchmark: "benchmarks/template_category/template_tool/{sample}.txt"
    
    # [TEMPLATE] Provide the path to the isolated Conda environment file.
    
    # [TEMPLATE] The actual bash commands to run the tool. Use {input}, {output}, {params}, etc.
    shell:
        """
        echo "{params.message} Sample: {wildcards.sample}" > {output.dummy_out} 2> {log}
        || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """
