rule motif_analysis:
    input:
        filtered_peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed"

    output:
        html=directory(f"{config['motif_analysis']['output']}/{{sample}}")

    params:
        motif_db=config['motif_analysis']['params']['motif_db'],
        genome_assembly=config['motif_analysis']['params']['genome_assembly']

    resources:
        mem_mb=config['motif_analysis']['resources']['mem_mb'],
        time=config['motif_analysis']['resources']['time']

    log: "logs/motif_analysis/{sample}.log"
    benchmark: "benchmarks/motif_analysis/{sample}.txt"
    conda: "envs/05_peak_calling/motif_analysis.yaml"
    container: "https://depot.galaxyproject.org/singularity/homer:4.11--pl526hc9558a2_3"
    threads: config['motif_analysis']['threads']
    message: "[Motif analysis] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | Output: {output.html}"

    shell:
        """
        if [ ! -s {input.filtered_peaks} ] || [ $(wc -l < {input.filtered_peaks}) -eq 0 ]; then
            echo "[WARNING] Peak file is empty. Creating dummy motif analysis output." >> {log}
            mkdir -p {output.html}
            echo "<html><body>No peaks found for motif analysis.</body></html>" > {output.html}/homerResults.html
            echo "<html><body>No peaks found for motif analysis.</body></html>" > {output.html}/knownResults.html
            touch {output.html}/homerResults.txt {output.html}/knownResults.txt
        else
            findMotifsGenome.pl {input.filtered_peaks} {params.genome_assembly} {output.html} \
                -p {threads} \
                -len 8,10,12 \
                -size 200 \
            2> {log}
        fi
        """

