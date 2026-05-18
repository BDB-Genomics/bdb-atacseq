#!/usr/bin/env bash
set -euo pipefail

ENVS=(
  rules/envs/02_alignment/chromap.yaml
  rules/envs/02_alignment/bowtie2.yaml
  rules/envs/scatac/archr.yaml
  rules/envs/scatac/cicero.yaml
  rules/envs/06_visualization/bedGraph_to_bigwig.yaml
  rules/envs/06_visualization/sorted_bedgraph.yaml
  rules/envs/06_visualization/deeptools.yaml
  rules/envs/03_post_alignment/bedtools.yaml
  rules/envs/03_post_alignment/samtools.yaml
  rules/envs/misc/template_tool.yaml
  rules/envs/05_peak_calling/tobias.yaml
  rules/envs/05_peak_calling/chipseeker.yaml
  rules/envs/05_peak_calling/homer.yaml
  rules/envs/05_peak_calling/macs2.yaml
  rules/envs/05_peak_calling/idr.yaml
  rules/envs/05_peak_calling/motif_analysis.yaml
  rules/envs/05_peak_calling/chromvar.yaml
  rules/envs/05_peak_calling/diff_accessibility.yaml
  rules/envs/05_peak_calling/consensus.yaml
  rules/envs/05_peak_calling/footprinting.yaml
  rules/envs/01_preprocessing/fastp.yaml
  rules/envs/01_preprocessing/fastqc.yaml
  rules/envs/01_preprocessing/multiqc.yaml
  rules/envs/04_metrics_qc/picard.yaml
  rules/envs/04_metrics_qc/qualimap.yaml
  rules/envs/04_metrics_qc/fragment_size_analysis.yaml
  rules/envs/04_metrics_qc/tss_enrichment.yaml
  rules/envs/04_metrics_qc/cross_correlation.yaml
  rules/envs/04_metrics_qc/preseq.yaml
  rules/envs/04_metrics_qc/qc_gate.yaml
  rules/envs/04_metrics_qc/fragment_analysis.yaml
)

PASS=()
FAIL=()
ENV_NAME="__env_test_tmp__"

for yaml in "${ENVS[@]}"; do
  echo "==> Testing: $yaml"
  # Clean up any leftover env from previous run
  /home/himanshu/miniconda3/bin/conda env remove -n "$ENV_NAME" -y 2>/dev/null || true

  if /home/himanshu/miniconda3/bin/conda env create -n "$ENV_NAME" -f "$yaml" 2>&1 | tee /tmp/env_test.log; then
    echo "    PASS"
    PASS+=("$yaml")
    /home/himanshu/miniconda3/bin/conda env remove -n "$ENV_NAME" -y 2>/dev/null || true
  else
    ERR=$(tail -5 /tmp/env_test.log | tr '\n' ' ')
    echo "    FAIL: $ERR"
    FAIL+=("$yaml|||$ERR")
    /home/himanshu/miniconda3/bin/conda env remove -n "$ENV_NAME" -y 2>/dev/null || true
  fi
done

echo ""
echo "===== RESULTS ====="
echo "PASSED: ${#PASS[@]}"
echo "FAILED: ${#FAIL[@]}"

if [ ${#FAIL[@]} -gt 0 ]; then
  echo ""
  echo "| File | Error |"
  echo "|------|-------|"
  for entry in "${FAIL[@]}"; do
    file="${entry%%|||*}"
    err="${entry##*|||}"
    echo "| $file | $err |"
  done
fi
