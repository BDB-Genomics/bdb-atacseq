# LAYER 1: Base Image (Pulled from Docker Hub)
# We use micromamba because it's a tiny, lightning-fast C++ implementation of Conda
FROM mambaorg/micromamba:1.5-bullseye-slim

LABEL maintainer="Himanshu Bhandary <2032ushimanshu@gmail.com>"
LABEL description="Host runner environment for BDB-Genomics ATAC-seq Pipeline"

# Set working directory inside the container
WORKDIR /app

# LAYER 2: Copy the environment file and create the Conda environment
# We do this BEFORE copying the rest of the code. Why? 
# Because Docker caches layers. If you change a python script later, 
# Docker will reuse this heavy installation layer from the cache!
# Note: envs/main.yaml provides the *host runner* dependencies (Snakemake & Python).
# Individual rule dependencies are resolved dynamically via Conda/Containers at runtime.
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/main.yaml /tmp/env.yaml

RUN micromamba install -y -n base -f /tmp/env.yaml && \
    micromamba clean --all --yes

# LAYER 3: Copy the actual pipeline code into the container
COPY --chown=$MAMBA_USER:$MAMBA_USER . /app

# Ensure snakemake and installed binaries are in the system PATH
ENV PATH="/opt/conda/bin:$PATH"

# Set the entrypoint to run Snakemake under micromamba's environment wrapper.
# This allows passing Snakemake arguments directly to the docker run command
# (e.g., `docker run myimage --cores 8`).
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "snakemake"]

# Default to showing help if no arguments are provided
CMD ["--help"]
