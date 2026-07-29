rule macs2_peak_calling:
    input:
        shifted_bam=lambda wildcards: f"{config['macs2']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        peaks=f"{config['macs2']['output']['peaks']}/{{sample}}_peaks.narrowPeak"

    params:
        gsize=sum(int(line.strip().split()[1]) for line in open(config['global']['references']['genome_sizes'])),
        qval=config['macs2']['params']['qvalue'],
        nomodel=config['macs2']['params']['nomodel'],
        format=config['macs2']['params']['format'],
        dir=lambda wildcards, output: __import__('os').path.dirname(output.peaks)

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['macs2']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['macs2']['resources']['time'] * attempt,

    log: "logs/macs2/{sample}.err"
    benchmark: "benchmarks/macs2/{sample}.txt"
    conda: "envs/05_peak_calling/macs2.yaml" if config.get("use_conda", True) else None
    # Use the newest Linux 3.10 build; the older _4 image fails at runtime in CI
    # with an undefined symbol error when importing MACS2's compiled extension.
    container: "docker://quay.io/biocontainers/macs2:2.2.9.1--py310h1fe012e_5" if config.get("use_container", True) else None
    threads: config['macs2']['threads']
    message: "[MACS2 PEAKCALLING] SAMPLE:  {wildcards.sample} | Shifted_Bam: {input.shifted_bam} | Peaks: {output.peaks} | Genome Size: {params.gsize} | QVal: {params.qval} | Nomodel: {params.nomodel} | Model: {params.format}]"

    shell:
        """
        MACS2_BOOTSTRAP_DIR=".snakemake/macs2_source"
        MACS2_SITE_DIR="${MACS2_BOOTSTRAP_DIR}/site"
        MACS2_SENTINEL="${MACS2_BOOTSTRAP_DIR}/.installed"

        # Bioconda / container builds of MACS2 can ship a broken compiled extension
        # on some Linux images. If importing the callpeak module fails, rebuild it
        # from source into a shared local prefix and prefer that version via PYTHONPATH.
        if ! python - <<'PY'
from MACS2.callpeak_cmd import run
PY
        then
            mkdir -p "${MACS2_BOOTSTRAP_DIR}"
            (
                flock -x 9
                if [ ! -f "${MACS2_SENTINEL}" ]; then
                    python -m pip install --no-cache-dir --no-binary MACS2 --no-deps --target "${MACS2_SITE_DIR}" "MACS2==2.2.9.1" >> {log} 2>&1
                    touch "${MACS2_SENTINEL}"
                fi
            ) 9>"${MACS2_BOOTSTRAP_DIR}/install.lock"
            if [ -z "${PYTHONPATH:-}" ]; then
                export PYTHONPATH="${MACS2_SITE_DIR}"
            else
                export PYTHONPATH="${MACS2_SITE_DIR}:${PYTHONPATH}"
            fi
        fi

        macs2 callpeak \
            -t {input.shifted_bam} \
            -f {params.format} \
            -g {params.gsize} \
            -n {wildcards.sample} \
            --outdir {params.dir} \
            {params.nomodel} \
            -q {params.qval} \
            2> {log}

         """
