rule frip_calculation:
    input:
        filtered_peaks=lambda wildcards: f"{config['frip_calculation']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        shifted_bam=lambda wildcards: f"{config['frip_calculation']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        frip=f"{config['frip_calculation']['output']}/{{sample}}_frip.txt"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['frip_calculation']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['frip_calculation']['resources']['time'] * attempt,

    log: "logs/frip/{sample}.err"
    benchmark: "benchmarks/frip/{sample}.txt"
    conda: "envs/03_post_alignment/bedtools.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:a0ffedb52808e102887f6ce600d092675bf3528a-0" if config.get("use_container", True) else None
    threads: config['frip_calculation']['threads']
    message: "[FRiP calculation] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | BAM: {input.shifted_bam} | Output: {output.frip}"
        
    shell:
        """
        (
        total_fragments=$(samtools view -c -f 64 {input.shifted_bam})
        fragments_in_peaks=$(bedtools coverage -counts -a {input.filtered_peaks} -b {input.shifted_bam} | awk '{{sum += $NF}} END {{print sum+0}}')
        frip=$(echo "scale=6; ${{fragments_in_peaks}} / ${{total_fragments}}" | bc)
        echo -e "FRiP\t$frip"  > {output.frip}
        echo -e "..................................................................." >> {output.frip}
        echo -e "Sample\\tTotal_Reads\\tReads_in_Peaks\\tFRiP_Score" >> {output.frip}
        echo -e "{wildcards.sample}\\t$total_fragments\\t$fragments_in_peaks\\t$frip" >> {output.frip}
        ) 2> {log}
        """
