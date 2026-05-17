rule motif_analysis:
    input:
        filtered_peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        genome=config['motif_analysis']['input']['genome']

    output:
        html=directory(f"{config['motif_analysis']['output']}/{{sample}}_motifs")

    params:
        motif_db=config['motif_analysis']['params']['motif_db']
    
    resources:
        mem_mb=config['motif_analysis']['resources']['mem_mb'],
        time=config['motif_analysis']['resources']['time']
            
    log: "logs/motif_analysis/{sample}.err"
    benchmark: "benchmarks/motif_analysis/{sample}.txt" 
    conda: "envs/05_peak_calling/homer.yaml"
    container: "https://depot.galaxyproject.org/singularity/homer:4.11--pl526hc9558a2_3"
    threads: config['motif_analysis']['threads']
    message: "[Motif analysis] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | Output: {output.html}"
    
    shell:
        """
        # Ensure containing output directory exists
        mkdir -p "$(dirname "{output.html}")"

        # HOMER requires write permissions to create a 'preparsed' directory in the genome folder.
        # If write permissions are unavailable, HOMER automatically falls back to parsing on-the-fly.
        findMotifsGenome.pl {input.filtered_peaks} {input.genome} {output.html} \
            -p {threads} \
            2> {log}
        """
