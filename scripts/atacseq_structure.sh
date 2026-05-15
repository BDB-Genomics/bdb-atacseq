#!/bin/bash
echo "Creating directories, nested directories and conda environment yaml file to automatically create project heirarchial directory structure"

#.................Creating directories to organize the files into sections which relflect their broad function....................
mkdir QualityControlAndPreprocessing 
mkdir -p AlignmentAndPostAlignmentProcessing/npm
mkdir PeakCallingAndAnalysis
mkdir VisualizationAndDownstream
mkdir Miscellaneous
mkdir HOMER
mkdir GREAT
mkdir clusterProfiler
#.................................Creating files for additional tools..............................................................
#PeakCallingAndAnalysis
touch PeakCallingAndAnalysis/Genrich.yaml 
touch PeakCallingAndAnalysis/HOMER.yaml 
touch PeakCallingAndAnalysis/GREAT yaml 

#AlignmentAndPostAlignment
touch AlignmentAndPostAlignmentProcessing/BWA.yaml
touch AlignmentAndPostAlignmentProcessing/minimap2.yaml 

#QualityControlAndPreprocessing
touch QualityControlAndPreprocessing/trim-galore.yaml 
touch QualityControlAndPreprocessing/bowtie1.yaml 
touch QualityControlAndPreprocessing/mito-ATAC.yaml

#VisualizationAndDownstream 
touch VisualizationAndDownstream/pyGenomeTracks.yaml 
touch VisualizationAndDownstream/ComplexHeatmap.yaml

#HOMER
touch HOMER/homer.yaml

#GREAT
touch GREAT/great.yaml

#clusterProfile
touch clusterProfile/clusterProfile.yaml

#README
for dir in */; do "touch ${dir}README.md"; done


#................................Moving files into relevant sections................................................................

#AlignmentAndPostAlignment
mv bowtie2.yaml samtools_*.yaml samtools_view.yaml  picard_*.yaml bedtools.yaml Picard_AlignmentSummaryMetrics.yaml  AlignmentAndPost*

#QualityAndPreprocessing
mv fastp.yaml fastqc.yaml multiqc.yaml qualimap_bamqc.yaml preseq.yaml  phantompeakqualtools.yaml QualityControl*

#PeakCallingAndAnalysis
mv macs2_peakcall.yaml idr.yaml ChIPseeker.yaml diffbind.yaml PeakCalling*

#VisualizationAndDownstream
mv deepTools.yaml igvtools.yaml ChIPseeker.yaml preseq_visualization.yaml  Visuali*
 


echo "Operation Successfull"




