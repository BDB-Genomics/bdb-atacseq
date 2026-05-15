rule qc_gate:
    input:
        frip=f"{config['qc_gate']['input']['frip']}/{{sample}}_frip.txt",
        tss=f"{config['qc_gate']['input']['tss']}/{{sample}}_tss_enrichment.txt",
        stats=f"{config['qc_gate']['input']['stats']}/{{sample}}_postFiltering.stats.txt"
        
    output:
        pass_file=f"{config['qc_gate']['output']}/{{sample}}_qc_pass.txt"
        
    params:
        min_frip=config['qc_gate']['params']['min_frip'],
        min_tss=config['qc_gate']['params']['min_tss_enr'],
        min_mapping_pt=config['qc_gate']['params']['min_mapping_rate'],
        max_dup_pt=config['qc_gate']['params']['max_duplicate_rate']
        
    resources:
        mem_mb=config['qc_gate']['resources']['mem_mb'],
        time=config['qc_gate']['resources']['time']
        
    threads: config['qc_gate']['threads']
    
    log: f"logs/qc_gate/{{sample}}.log"
    
    benchmark: f"benchmarks/qc_gate/{{sample}}.txt"
    
    message: "[QC GATE] Checking ATAC-seq metrics for Sample: {wildcards.sample}"
    
    shell:
        """
        python3 rules/scripts/parse_qc_metrics.py \
            --sample {wildcards.sample} \
            --frip-file {input.frip} \
            --tss-file {input.tss} \
            --stats-file {input.stats} \
            --min-frip {params.min_frip} \
            --min-tss {params.min_tss} \
            --min-mapping-rate {params.min_mapping_pt} \
            --max-duplicate-rate {params.max_dup_pt} \
            --log {log} \
            --output {output.pass_file}
        """
