import fcntl
import os
import subprocess
import sys
from pathlib import Path


def _log_handle():
    log_path = Path(snakemake.log[0])
    log_path.parent.mkdir(parents=True, exist_ok=True)
    return log_path.open("a", encoding="utf-8")


def _can_import_macs2() -> bool:
    try:
        import MACS2.callpeak_cmd  # noqa: F401

        return True
    except Exception:
        return False


def _bootstrap_from_source(log_file) -> None:
    bootstrap_dir = Path(snakemake.params.bootstrap_dir)
    site_dir = Path(snakemake.params.site_dir)
    sentinel = Path(snakemake.params.sentinel)
    lock_path = bootstrap_dir / "install.lock"

    bootstrap_dir.mkdir(parents=True, exist_ok=True)
    site_dir.mkdir(parents=True, exist_ok=True)

    with lock_path.open("w", encoding="utf-8") as lock_handle:
        fcntl.flock(lock_handle, fcntl.LOCK_EX)
        if not sentinel.exists():
            cmd = [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--no-cache-dir",
                "--no-binary",
                "MACS2",
                "--no-deps",
                "--target",
                str(site_dir),
                "MACS2==2.2.9.1",
            ]
            subprocess.run(cmd, check=True, stdout=log_file, stderr=log_file)
            sentinel.touch()


def main() -> None:
    with _log_handle() as log_file:
        if not _can_import_macs2():
            print(
                "[MACS2] Prebuilt package import failed, bootstrapping from source.",
                file=log_file,
            )
            _bootstrap_from_source(log_file)

        site_dir = str(Path(snakemake.params.site_dir))
        env = os.environ.copy()
        env["PYTHONPATH"] = (
            site_dir
            if not env.get("PYTHONPATH")
            else f"{site_dir}:{env['PYTHONPATH']}"
        )

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

        subprocess.run(cmd, check=True, stdout=log_file, stderr=log_file, env=env)


if __name__ == "__main__":
    main()
