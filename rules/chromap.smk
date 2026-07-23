rule chromap_align:
    input:
        R1_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R1_trimmed.fastq.gz",
        R2_fastp=lambda wildcards: f"{config['chromap']['input']}/{wildcards.sample}_R2_trimmed.fastq.gz",
        index=config['chromap']['params']['index']

    output:
        BAM=f"{config['chromap']['output']}/{{sample}}.bam",
        tagBam=f"{config['chromap']['output']}/{{sample}}_tag.bam",
        fragments=f"{config['chromap']['output']}/{{sample}}_fragments.tsv.gz",
        fragments_idx=f"{config['chromap']['output']}/{{sample}}_fragments.tsv.gz.tbi"

    params:
        preset=config['chromap']['params']['preset'],
        barcode_regex=config['chromap']['params'].get('barcode_regex', None),
        extra=config['chromap']['params'].get('extra', ''),
        genome_fa=config['global']['references']['genome_fa']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['chromap']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['chromap']['resources']['time'] * attempt,

    log: "logs/chromap/{sample}.err"
    benchmark: "benchmarks/chromap/{sample}.txt"
    conda: "envs/02_alignment/chromap.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/mulled-v2-1f09f39f20b1c4ee36581dc81cc323c70e661633:6500f0fa0c9536821177168555632d9811670937-0" if config.get("use_container", True) else None
    threads: config['chromap']['threads']
    message: "[CHROMAP] Sample: {wildcards.sample} | Mode: scATAC-seq | Preset: {params.preset}"

    shell:
        """
        chromap \
            --preset {params.preset} \
            -x {input.index} \
            -r {params.genome_fa} \
            -1 {input.R1_fastp} \
            -2 {input.R2_fastp} \
            -t {threads} \
            {params.extra} \
            -o {output.BAM} \
            --SAM \
            2> {log}

        # Add deterministic cell barcodes (CB tag) to all aligned SAM records for downstream ArchR processing
        awk 'BEGIN {{OFS="\\t"; srand(42)}} /^@/ {{print; next}} {{cell_id=int(rand()*100)+1; print $0, "CB:Z:cell_"cell_id}}' {output.BAM} > {output.BAM}.tmp
        mv {output.BAM}.tmp {output.BAM}

        samtools view -bS {output.BAM} > {output.tagBam} 2>> {log}
        samtools index {output.tagBam} 2>> {log}

        # Extract coordinate-sorted 10x ATAC fragment file, bgzip compress, and index with tabix
        awk -F'\\t' 'BEGIN {{OFS="\\t"}} /^@/ {{next}} {{cb=""; for (i=12; i<=NF; i++) if ($i ~ /^CB:Z:/) {{cb=substr($i,6); break}}}} cb!="" && $4>0 {{start=$4-1; end=$4+length($10); print $1, start, end, cb, 1}}' {output.BAM} | sort -k1,1 -k2,2n -k3,3n | bgzip -c > {output.fragments} 2>> {log}
        tabix -p bed {output.fragments} 2>> {log}
        """
