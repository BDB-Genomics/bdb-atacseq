rule consensus_peaks:
    input:
        peaks=expand("{path}/{sample}_filtered_peaks.bed", path=config['blacklist_filter']['output']['filtered_peaks'], sample=SAMPLES)

    output:
        consensus=f"{config['consensus_peaks']['output']['consensus']}/consensus_peaks.bed",
        counts=f"{config['consensus_peaks']['output']['counts']}/peak_sample_counts.txt"

    params:
        min_samples=config['consensus_peaks']['params']['min_samples'],
        merge_distance=config['consensus_peaks']['params']['merge_distance'],
        n_peaks=lambda wildcards, input: len(input.peaks)

    resources:
        mem_mb=config['consensus_peaks']['resources']['mem_mb'],
        time=config['consensus_peaks']['resources']['time']

    log: "logs/consensus_peaks/consensus.err"
    benchmark: "benchmarks/consensus_peaks/consensus.txt"
    conda: "envs/05_peak_calling/consensus.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['consensus_peaks']['threads']
    message: "[Consensus Peaks] Merging {params.n_peaks} peak sets | Min samples: {params.min_samples}"

    shell:
        """
        cat {input.peaks} | sort -k1,1 -k2,2n > {output.consensus}.merged.tmp

        bedtools merge -i {output.consensus}.merged.tmp \
            -d {params.merge_distance} \
            -c 1 \
            -o count \
        > {output.consensus}.counted.tmp

        awk -v min="$(( {params.min_samples} ))" '$4 >= min' {output.consensus}.counted.tmp \
        > {output.consensus}

        cut -f1-3,4 {output.consensus} > {output.counts}

        rm -f {output.consensus}.merged.tmp {output.consensus}.counted.tmp
        """
