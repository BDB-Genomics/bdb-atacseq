rule fragment_size_analysis:
    input:
        metrics=lambda wildcards: f"{config['fragment_size_analysis']['input']['metrics']}/{wildcards.sample}.insert_metrics.txt"
        
    output:
        fragment_sizes=config['fragment_size_analysis']['output'] + "/{sample}_fragment_sizes.txt", 
        histogram=config['fragment_size_analysis']['output'] + "/{sample}_fragment.png", 
        stats=config['fragment_size_analysis']['output'] + "/{sample}_fragment_stats.txt"
    
    params:
        min_length=config['fragment_size_analysis']['params']['min_length'], 
        max_length=config['fragment_size_analysis']['params']['max_length'],  
        max_fragment=config['fragment_size_analysis']['params']['max_fragment'],    
        sample="{sample}"
        
    resources:
        mem_mb=config['fragment_size_analysis']['resources']['mem_mb'], 
        time=config['fragment_size_analysis']['resources']['time']

    log: "logs/fragment_size_analysis/{sample}.err"
    benchmark: "benchmarks/fragment_size_analysis/{sample}.txt"
    conda: "envs/04_metrics_qc/fragment_size_analysis.yaml"
    container: "https://depot.galaxyproject.org/singularity/picard:3.0.0--hdfd78af_1"
    threads: config['fragment_size_analysis']['threads']
    message: "[FRAGMENT SIZE ANALYSIS] SAMPLES: {wildcards.sample}| INPUT: {input.metrics}| OUTPUT: {output.fragment_sizes} {output.histogram} {output.stats}|MIN LENGTH: {params.min_length}| MAX LENGTH: {params.max_length}| MAX FRAGMENT: {params.max_fragment} "
        
    shell:
        """
        echo '
        # Read Picard insert size metrics dynamically by searching for the data table start
        metrics_file <- "{input.metrics}"
        all_lines <- readLines(metrics_file)
        skip_lines <- grep("^insert_size", all_lines)
        if (length(skip_lines) == 0) {
            skip_lines <- grep("## HISTOGRAM", all_lines)
        }
        if (length(skip_lines) == 0) {
            skip_lines <- 10  # Fallback
        } else {
            skip_lines <- skip_lines[1] - 1
        }

        data <- read.table(metrics_file, header=TRUE, skip=skip_lines)
        fragments <- data$insert_size
     
        # Write fragment sizes
        write.table(fragments, "{output.fragment_sizes}", row.names=FALSE, col.names=FALSE, quote=FALSE)
     
        # Generate histogram
        tryCatch({
            png("{output.histogram}")
            hist(fragments, main="Fragment Size Distribution", xlab="Fragment Size (bp)", col="skyblue", breaks=50)
            dev.off()
        }, error = function(e) {
            cat("Plot generation failed:", conditionMessage(e), "\n")
        })
     
        # Generate statistics
        stats_summary <- c(
              paste("Total_fragments:", length(fragments)),
              paste("Mean_size:", round(mean(fragments), 2)),
              paste("Min_size:", min(fragments)),
              paste("Max_size:", max(fragments))
        )
        writeLines(stats_summary, "{output.stats}")
        ' | Rscript - 2> {log}
        """
