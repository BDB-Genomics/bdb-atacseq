rule calculate_mito_reads:
    input:
        sorted_bam=lambda wildcards: f"{config['mitoATAC_calculate']['input']['sorted_bam']}/{wildcards.sample}.sorted.bam"
        
    output:
        mito_stats=f"{config['mitoATAC_calculate']['output']['mito_stats']}/{{sample}}_mito_stats.txt"
        
    params:
        mito_chr=config['mitoATAC_calculate']['params']['mito_chr']
    
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['mitoATAC_calculate']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['mitoATAC_calculate']['resources']['time'] * attempt,
            

    log: "logs/mitoATAC_calculate/{sample}.err"
    benchmark: "benchmarks/mitoATAC_calculate/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['mitoATAC_calculate']['threads']
    message: "[MITOCHONDRIAL READS] SAMPLES: {wildcards.sample}|INPUT: {input.sorted_bam}|OUTPUT: {output.mito_stats}|PATTERN: {params.mito_chr}"
        
    shell:
        """
        # Generate inline index for the raw sorted bam (required for samtools region query)
        samtools index -@ {threads} {input.sorted_bam}

        # Get BAM header chromosome names to dynamically locate MT/M/chrM/chrMT
        mito_chr=$(samtools view -H {input.sorted_bam} | grep -o -E "SN:(chr)?(M|MT)" | cut -d':' -f2 | head -n1)
        [ -z "$mito_chr" ] && mito_chr="{params.mito_chr}"

        
        # Total mapped reads (excluding unmapped)
        total=$(samtools view -c -F 4 {input.sorted_bam} 2>> {log})
        
        # Mitochondrial reads
        mito=0
        [ "${{total}}" -ne 0 ] && mito=$(samtools view -c {input.sorted_bam} "$mito_chr" 2>> {log})
        
        # Calculate fraction
        fraction=$(awk -v m="$mito" -v t="$total" 'BEGIN {{if (t > 0) printf "%.6f", m/t; else print "0.000000"}}')
        
        echo "Total Reads: ${{total}}" > {output.mito_stats}
        echo "Mito Reads: ${{mito}}" >> {output.mito_stats}
        echo "Mito Fraction: ${{fraction}}" >> {output.mito_stats}

        # Remove the inline index to keep the directory clean
        rm -f {input.sorted_bam}.bai
        """
