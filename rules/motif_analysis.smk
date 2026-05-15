rule motif_analysis:
    input:
        filtered_peaks=expand("{path}/{sample}_filtered_peaks.bed", path=config['blacklist_filter']['output']['filtered_peaks'], sample=SAMPLES),
        genome=config['motif_analysis']['input']['genome']

    output:
        html=directory(config['motif_analysis']['output'])

    params:
        motif_db=config['motif_analysis']['params']['motif_db']
    
    resources:
        mem_mb=config['motif_analysis']['resources']['mem_mb'],
        time=config['motif_analysis']['resources']['time']
            
    log: "logs/motif_analysis/motif_analysis.log"
    benchmark: "benchmarks/motif_analysis/motif_analysis.txt" 
    conda: "envs/05_peak_calling/homer.yaml"
    container: "https://depot.galaxyproject.org/singularity/homer:4.11--pl526hc9558a2_3"
    threads: config['motif_analysis']['threads']
    message: "[Motif analysis] Sample: All combined | Peaks: {input.filtered_peaks} | Output: {output.html}"
    
    shell:
        """
        cat {input.filtered_peaks} > merged_peaks.tmp
        findMotifsGenome.pl merged_peaks.tmp {input.genome} {output.html} \
            -p {threads} \
        2> {log}

        rm -rf merged_peaks.tmp
        """
