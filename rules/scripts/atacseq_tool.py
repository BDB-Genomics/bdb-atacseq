import subprocess
import os
import json
import yaml
from pathlib import Path
from typing import Optional

# LangChain community package is optional; we implement a standard Python function 
# that can be decorated with @tool or imported directly into agent workflows.
try:
    from langchain.tools import tool
except ImportError:
    # Fallback mock decorator if langchain isn't installed in the runner environment
    def tool(func):
        return func

@tool("run_atacseq_pipeline")
def run_atacseq_pipeline(
    profile: str = "local",
    cores: int = 8,
    use_conda: bool = True,
    batch_size: Optional[int] = None,
    config_override_path: Optional[str] = None,
    project_dir: str = "."
) -> str:
    """Exposes the BDB-Genomics ATAC-seq pipeline as a computational tool for AI Agents.
    
    This tool performs pre-flight checks on the configuration and runs the end-to-end
    modality-aware genomic analysis pipeline (covering fastp, Bowtie2/Chromap, MACS2,
    footprinting, and differential accessibility) using the designated execution profile.
    
    Args:
        profile: Execution environment profile ('local', 'slurm', 'low_resource', 'aws', 'gcp', 'azure', 'kubernetes')
        cores: Number of CPU cores to allocate (local runs only)
        use_conda: Resolve rule dependencies using Conda environments
        batch_size: If specified, runs in memory-efficient batched mode with this batch size
        config_override_path: Optional path to an override config yaml file to merge settings
        project_dir: Root directory of the ATACseq-pipeline repository
        
    Returns:
        A detailed string reporting execution status, performance metrics, or error logs.
    """
    proj_path = Path(project_dir).resolve()
    scripts_dir = proj_path / "rules" / "scripts"
    config_path = proj_path / "config.yaml"
    
    # 1. Run Pre-flight configuration checks
    val_script = scripts_dir / "validate_config.py"
    if val_script.exists():
        val_res = subprocess.run(
            ["python3", str(val_script), str(config_path)],
            capture_output=True,
            text=True,
            cwd=str(proj_path)
        )
        if val_res.returncode != 0:
            return f"Configuration Validation Failed:\n{val_res.stderr}\n{val_res.stdout}"
            
    # 2. Build the execution command
    if batch_size:
        run_script = scripts_dir / "run_batched.py"
        cmd = [
            "python3", str(run_script),
            "--batch-size", str(batch_size),
            "--cores", str(cores),
            "--profile", f"profile/{profile}"
        ]
        if use_conda:
            cmd.extend(["--conda-frontend", "conda"])
    else:
        cmd = [
            "snakemake",
            "--profile", f"profile/{profile}",
            "--cores", str(cores)
        ]
        if use_conda:
            cmd.extend(["--use-conda", "--conda-frontend", "conda"])
        if config_override_path:
            cmd.extend(["--configfile", str(config_path), str(config_override_path)])
            
    # 3. Execute
    try:
        run_res = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=str(proj_path)
        )
    except Exception as e:
        return f"Pipeline execution failed to start: {str(e)}"
        
    # 4. Check results and load structured summary if it exists
    summary_path = proj_path / "results" / "reporting" / "pipeline_execution_summary.json"
    structured_summary = ""
    if summary_path.exists():
        try:
            with open(summary_path, 'r') as sf:
                structured_summary = "\n\nStructured Summary:\n" + json.dumps(json.load(sf), indent=2)
        except Exception:
            pass
            
    if run_res.returncode != 0:
        return (
            f"Pipeline execution failed with exit code {run_res.returncode}.\n"
            f"Error details:\n{run_res.stderr}\n{run_res.stdout}{structured_summary}"
        )
        
    return f"Pipeline completed successfully!\nOutput metrics:\n{run_res.stdout}{structured_summary}"
