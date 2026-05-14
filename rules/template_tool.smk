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
    threads:
        config['template_category']['template_tool']['threads']
    resources:
        mem_mb=config['template_category']['template_tool']['resources']['mem_mb'],
        time=config['template_category']['template_tool']['resources']['time']
    
    # [TEMPLATE] Specify where logs and benchmarks will be saved.
    log:
        "logs/template_category/template_tool/{sample}.log"
    benchmark:
        "benchmarks/template_category/template_tool/{sample}.txt"
    
    # [TEMPLATE] Provide the path to the isolated Conda environment file.
    conda:
        "envs/misc/template_tool.yaml"
    
    # [TEMPLATE] The actual bash commands to run the tool. Use {input}, {output}, {params}, etc.
    shell:
        """
        echo "{params.message} Sample: {wildcards.sample}" > {output.dummy_out}
        2> {log}
        """
