import os
import re

# Mapping of rule file basenames to Singularity URLs
CONTAINER_MAPPING = {
    "bedtools_genomecov.smk": "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3",
    "bigwig.smk": "https://depot.galaxyproject.org/singularity/ucsc-bedgraphtobigwig:377--h4463345_0",
    "blacklist_filter.smk": "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3",
    "bowtie2.smk": "https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02306649ee64e819b8830f69904d48507:6c2688b7762696e16544521798e29a9b1c76949b-0",
    "calculate_mito_reads.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "correlation_analysis.smk": "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0",
    "fastp.smk": "https://depot.galaxyproject.org/singularity/fastp:0.24.0--heae3180_1",
    "fastqc.smk": "https://depot.galaxyproject.org/singularity/fastqc:0.11.9--0",
    "fragment_size_analysis.smk": "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1",
    "frip_calculation.smk": "https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02306649ee64e819b8830f69904d48507:6c2688b7762696e16544521798e29a9b1c76949b-0",
    "heatmap.smk": "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0",
    "macs2_peak_calling.smk": "https://depot.galaxyproject.org/singularity/macs2:2.2.7.1--py38h4a9c2d4_3",
    "motif_analysis.smk": "https://depot.galaxyproject.org/singularity/homer:4.11--pl526hc9558a2_3",
    "multiqc.smk": "https://depot.galaxyproject.org/singularity/multiqc:1.14--pyhdfd78af_0",
    "normalize_coverage.smk": "https://depot.galaxyproject.org/singularity/deeptools:3.5.1--py_0",
    "peak_annotation.smk": "https://depot.galaxyproject.org/singularity/bioconductor-chipseeker:1.34.1--r42hdfd78af_0",
    "picard_alignment_metrics.smk": "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1",
    "picard_insert_size_metrics.smk": "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1",
    "preseq.smk": "https://depot.galaxyproject.org/singularity/preseq:3.1.2--h4455471_2",
    "qc_gate.smk": "https://depot.galaxyproject.org/singularity/python:3.10.4",
    "qualimap_bamqc.smk": "https://depot.galaxyproject.org/singularity/qualimap:2.2.2d--1",
    "remove_mito_reads.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_fixmate.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_index_after_markdup.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_index_post_filter.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_index.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_markdup.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_sort.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_stats.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "samtools_view.smk": "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0",
    "sorted_bedgraph.smk": "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3",
    "template_tool.smk": "https://depot.galaxyproject.org/singularity/python:3.10.4",
    "tn5_shift.smk": "https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02306649ee64e819b8830f69904d48507:6c2688b7762696e16544521798e29a9b1c76949b-0",
    "tss_enrichment.smk": "https://depot.galaxyproject.org/singularity/r-base:4.2.1"
}

def apply_container(filepath):
    filename = os.path.basename(filepath)
    if filename not in CONTAINER_MAPPING:
        print(f"Skipping {filename}: no mapping found.")
        return

    container_url = CONTAINER_MAPPING[filename]
    
    with open(filepath, 'r') as f:
        lines = f.readlines()

    directives = {
        'log': None,
        'conda': None,
        'container': f'"{container_url}"',
        'threads': None,
        'message': None
    }
    
    new_lines = []
    
    # 1. Extract existing directives and remove them
    i = 0
    while i < len(lines):
        line = lines[i]
        match = re.match(r'^    (log|conda|container|threads|message):\s*(.*)', line)
        if match:
            key = match.group(1)
            val = match.group(2).strip()
            if val:
                directives[key] = val
            else:
                # Multi-line (not expected given previous step but let's be safe)
                val_lines = []
                i += 1
                while i < len(lines) and lines[i].startswith('        '):
                    val_lines.append(lines[i].strip())
                    i += 1
                directives[key] = " ".join(val_lines)
                continue
        else:
            new_lines.append(line)
        i += 1

    # 2. Find insertion point (after resources)
    insert_idx = -1
    for i, line in enumerate(new_lines):
        if re.match(r'^    resources:', line):
            j = i + 1
            while j < len(new_lines) and (new_lines[j].startswith('        ') or new_lines[j].strip() == ''):
                j += 1
            insert_idx = j
            break
    
    if insert_idx == -1:
        # Fallback to params/output/input
        for target in ['params:', 'output:', 'input:']:
            for i, line in enumerate(new_lines):
                if re.match(f'^    {target}', line):
                    j = i + 1
                    while j < len(new_lines) and (new_lines[j].startswith('        ') or new_lines[j].strip() == ''):
                        j += 1
                    insert_idx = j
                    break
            if insert_idx != -1: break

    # 3. Reconstruct
    if insert_idx != -1:
        block = []
        if directives['log']: block.append(f"    log: {directives['log']}\n")
        if directives['conda']: block.append(f"    conda: {directives['conda']}\n")
        if directives['container']: block.append(f"    container: {directives['container']}\n")
        if directives['threads']: block.append(f"    threads: {directives['threads']}\n")
        if directives['message']: block.append(f"    message: {directives['message']}\n")
        
        while insert_idx < len(new_lines) and new_lines[insert_idx].strip() == '':
            new_lines.pop(insert_idx)
        
        new_lines.insert(insert_idx, "\n")
        for k, b_line in enumerate(block):
            new_lines.insert(insert_idx + 1 + k, b_line)
        new_lines.insert(insert_idx + 1 + len(block), "\n")

    final_content = "".join(new_lines)
    final_content = re.sub(r'\n{3,}', '\n\n', final_content)
    
    with open(filepath, 'w') as f:
        f.write(final_content)

if __name__ == "__main__":
    for f in os.listdir("rules"):
        if f.endswith(".smk"):
            print(f"Adding container to rules/{f}...")
            apply_container(os.path.join("rules", f))
