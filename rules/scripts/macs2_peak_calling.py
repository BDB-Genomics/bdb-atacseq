import subprocess
from pathlib import Path


def _log_handle():
    log_path = Path(snakemake.log[0])
    log_path.parent.mkdir(parents=True, exist_ok=True)
    return log_path.open("a", encoding="utf-8")


def main() -> None:
    with _log_handle() as log_file:
        cmd = [
            "macs2",
            "callpeak",
            "-t",
            snakemake.input.shifted_bam,
            "-f",
            snakemake.params.format,
            "-g",
            str(snakemake.params.gsize),
            "-n",
            snakemake.wildcards.sample,
            "--outdir",
            snakemake.params.dir,
        ]
        nomodel = str(snakemake.params.nomodel).strip()
        if nomodel and nomodel.lower() != "none":
            cmd.append(nomodel)
        cmd.extend(["-q", str(snakemake.params.qval)])

        subprocess.run(cmd, check=True, stdout=log_file, stderr=log_file)


if __name__ == "__main__":
    main()
