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
        mem_mb=config['peak_annotation']['resources']['mem_mb'],
        time=config['peak_annotation']['resources']['time']

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

        txdb <- makeTxDbFromGFF("{params.gff}", format="gtf");
        peakAnno <- annotatePeak(peakfile, TxDb=txdb, tssRegion=c(-3000, 3000), verbose=FALSE);

        write.table(as.data.frame(peakAnno), "{output.annotation}", sep="\t", row.names=FALSE, quote=FALSE);

        feature_summary <- as.data.frame(table(peakAnno@anno$annotation));
        write.table(feature_summary, "{output.summary}", sep="\t", row.names=FALSE, quote=FALSE)' \
        2> {log}
        """
