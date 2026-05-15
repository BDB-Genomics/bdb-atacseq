rule blacklist_region_filter:
    input:
        peaks=lambda wildcards: f"{config['blacklist_filter']['input']['peaks']}/{wildcards.sample}_peaks.narrowPeak"

    output:
        filtered_peaks=f"{config['blacklist_filter']['output']['filtered_peaks']}/{{sample}}_filtered_peaks.bed"
        
    params:
        blacklist=config['blacklist_filter']['params']['blacklist']
    resources:
        mem_mb=config['blacklist_filter']['resources']['mem_mb'], 
        time=config['blacklist_filter']['resources']['time']

    benchmark:
        "benchmarks/blacklist_region_filter/{sample}.txt"
        
    log:
        "logs/blacklist_region_filter/{sample}.err"
            
    conda:  
        "envs/03_post_alignment/bedtools.yaml"

    threads: 
        config['blacklist_filter']['threads']
        
    message:
        "[Bedtools intersect] Sample: {wildcards.sample} | Peaks: {input.peaks} | Filtered Peaks: {output.filtered_peaks} | Blacklist: {params.blacklist}"

    shell:
        """
        awk 'BEGIN {{OFS="\\t"}} {{if ($1 ~ /^[0-9]+$/ || $1 == "X" || $1 == "Y" || $1 == "MT") $1="chr"$1; print}}' {input.peaks} > {input.peaks}.tmp && \
        bedtools intersect -v \
            -a {input.peaks}.tmp  \
            -b {params.blacklist} \
        > {output.filtered_peaks} 
        2> {log} 
         
        rm -rf {input.peaks}.tmp
        """

