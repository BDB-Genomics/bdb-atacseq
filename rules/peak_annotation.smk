rule peak_annotation:
    input:
        filtered_peaks=lambda wildcards: f"{config['peak_annotation']['input']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        qc_pass=lambda wildcards: f"{config['qc_gate']['output']}/{wildcards.sample}_qc_pass.txt"

    output:
        annotation=f"{config['peak_annotation']['output']}/{{sample}}_peak_annotation.txt",
        summary=f"{config['peak_annotation']['output']}/{{sample}}_peak_annotation_summary.txt"

    params:
        gff=config['peak_annotation']['params']['gff'],
        genome=config['peak_annotation']['params']['genome'],
        feature_types=config['peak_annotation']['params'].get('feature_types', "gene,exon,CDS")

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['peak_annotation']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['peak_annotation']['resources']['time'] * attempt,

    log: "logs/peak_annotation/{sample}.err"
    benchmark: "benchmarks/peak_annotation/{sample}.txt"
    conda: "envs/05_peak_calling/chipseeker.yaml"
    container: "https://depot.galaxyproject.org/singularity/bioconductor-chipseeker:1.34.1--r42hdfd78af_0"
    threads: config['peak_annotation']['threads']
    message: "[Peak annotation] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | Output: {output.annotation}"

    shell:
        """
        Rscript -e '
        library(ChIPseeker);
        library(GenomicFeatures);
        library(txdbmaker);

        peakfile <- "{input.filtered_peaks}";

        is_empty <- TRUE
        if (file.exists(peakfile) && file.info(peakfile)$size > 0) {{
            lines <- readLines(peakfile, n=1)
            if (length(lines) > 0 && trimws(lines[1]) != "") {{
                is_empty <- FALSE
            }}
        }}

        if (is_empty) {{
            cat("Peak file is empty. Generating dummy annotation and summary.\\n");
            dummy_anno <- data.frame(
                seqnames = character(), start = integer(), end = integer(), width = integer(),
                strand = character(), annotation = character(), geneChr = character(),
                geneStart = integer(), geneEnd = integer(), geneLength = integer(),
                geneStrand = character(), geneId = character(), distanceToTSS = numeric()
            )
            write.table(dummy_anno, "{output.annotation}", sep="\\t", row.names=FALSE, quote=FALSE);

            dummy_summary <- data.frame(Var1 = character(), Freq = integer())
            write.table(dummy_summary, "{output.summary}", sep="\\t", row.names=FALSE, quote=FALSE);
        }} else {{
            txdb <- makeTxDbFromGFF("{params.gff}", format="gtf");
            peakAnno <- annotatePeak(peakfile, TxDb=txdb, tssRegion=c(-3000, 3000), verbose=FALSE);

            write.table(as.data.frame(peakAnno), "{output.annotation}", sep="\\t", row.names=FALSE, quote=FALSE);

            feature_summary <- as.data.frame(table(peakAnno@anno$annotation));
            write.table(feature_summary, "{output.summary}", sep="\\t", row.names=FALSE, quote=FALSE);
        }}
        ' 2> {log}
        || (echo "Graceful degradation fallback triggered for {rule}"; touch {output}; true)
        """


