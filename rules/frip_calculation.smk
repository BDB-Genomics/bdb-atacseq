rule frip_calculation:
    input:
        filtered_peaks=lambda wildcards: f"{config['frip_calculation']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        shifted_bam=lambda wildcards: f"{config['frip_calculation']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        frip=f"{config['frip_calculation']['output']}/{{sample}}_frip.txt"

    resources:
        mem_mb=config['frip_calculation']['resources']['mem_mb'], 
        time=config['frip_calculation']['resources']['time']

    log: "logs/frip/{sample}.err"
    benchmark: "benchmarks/frip/{sample}.txt"
    conda: "envs/03_post_alignment/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02306649ee64e819b8830f69904d48507:6c2688b7762696e16544521798e29a9b1c76949b-0"
    threads: config['frip_calculation']['threads']
    message: "[FRiP calculation] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | BAM: {input.shifted_bam} | Output: {output.frip}"
        
    shell:
        """
        total_reads=$(samtools view -c -F 260 {input.shifted_bam} 2> {log})
        reads_in_peaks=$(bedtools coverage -a {input.filtered_peaks} -b {input.shifted_bam} 2>> {log} | awk '{{sum += $11}} END {{print sum+0}}')
        
        frip=$(awk -v rip="$reads_in_peaks" -v tr="$total_reads" 'BEGIN {{if (tr > 0) printf "%.6f", rip/tr; else print "0.000000"}}')
        
        echo -e "FRiP\\t$frip"  > {output.frip}
        echo -e "..................................................................." >> {output.frip}
        echo -e "Sample\\tTotal_Reads\\tReads_in_Peaks\\tFRiP_Score" >> {output.frip}
        echo -e "{wildcards.sample}\\t$total_reads\\t$reads_in_peaks\\t$frip" >> {output.frip}
        """
