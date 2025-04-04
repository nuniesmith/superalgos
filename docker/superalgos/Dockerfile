###############################
# Stage 1: Builder
###############################
ARG CUDA_VERSION=12.8.0
ARG CUDNN_VERSION=cudnn
ARG UBUNTU_VERSION=ubuntu24.04
ARG NODE_VERSION=18

FROM nvidia/cuda:${CUDA_VERSION}-${CUDNN_VERSION}-devel-${UBUNTU_VERSION} AS builder

# Build arguments
ARG GITHUB_REPO=https://github.com/Superalgos/Superalgos.git
ARG BRANCH=master
ARG EXTRA_BUILD_PACKAGES=""

WORKDIR /app

# Install build dependencies - using build cache for apt
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    p7zip-full \
    unzip \
    bash \
    git \
    make \
    g++ \
    python3 \
    tzdata \
    ${EXTRA_BUILD_PACKAGES} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone the repository
RUN git clone --depth 1 --branch ${BRANCH} ${GITHUB_REPO} . \
    && npm ci --omit=optional \
    && chmod +x ./Docker/download-plugins.sh \
    && ./Docker/download-plugins.sh

# Create required directories
RUN mkdir -p \
    ./Platform/My-Data-Storage \
    ./Platform/My-Log-Files/Platform \
    ./Platform/My-Workspaces \
    ./Platform/My-Network-Nodes-Data \
    ./Platform/My-Social-Trading-Data \
    ./Platform/My-Secrets \
    ./Platform/My-PM2-Data

###############################
# Stage 2: Runtime
###############################
FROM nvidia/cuda:${CUDA_VERSION}-${CUDNN_VERSION}-runtime-${UBUNTU_VERSION} AS runtime

# Runtime arguments with defaults
ARG NODE_VERSION=18
ARG SERVICE_PORT=34248
ARG SERVICE_NAME="superalgos"
ARG APP_VERSION=1.0.0
ARG USER_NAME=superalgos
ARG USER_ID=1001
ARG GROUP_ID=1001
ARG EXTRA_RUNTIME_PACKAGES=""

# Set runtime environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS=--max_old_space_size=8192 \
    PM2_HOME=/app/Platform/My-PM2-Data \
    DEBIAN_FRONTEND=noninteractive

# CUDA environment
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

WORKDIR /app

# Install only necessary runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    python3 \
    tzdata \
    tini \
    ${EXTRA_RUNTIME_PACKAGES} \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a dedicated non-root user
RUN groupadd -g ${GROUP_ID} ${USER_NAME} 2>/dev/null || true && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -m ${USER_NAME} 2>/dev/null || true

# Copy application from builder stage
COPY --from=builder --chown=${USER_NAME}:${USER_NAME} /app /app

# Set permissions for all directories
RUN chmod -R 775 /app

# Label the image with metadata
LABEL org.opencontainers.image.title="${SERVICE_NAME}" \
    org.opencontainers.image.version="${APP_VERSION}" \
    org.opencontainers.image.vendor="Superalgos" \
    org.opencontainers.image.description="GPU-enabled container for Superalgos trading platform" \
    org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    org.opencontainers.image.source="https://github.com/Superalgos/Superalgos" \
    com.nvidia.volumes.needed="nvidia_driver"

# Expose the service ports
EXPOSE 34248 18041 18043

# Volumes for persistent data
VOLUME ["/app/Platform/My-Data-Storage", \
"/app/Platform/My-Log-Files", \
"/app/Platform/My-Workspaces", \
"/app/Platform/My-Network-Nodes-Data", \
"/app/Platform/My-Social-Trading-Data", \
"/app/Platform/My-Secrets", \
"/app/Platform/My-PM2-Data"]

# Health Check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl --fail http://localhost:34248/health || nvidia-smi > /dev/null || exit 1

# Switch to non-root user
USER ${USER_NAME}

# Use tini as init system
ENTRYPOINT ["/usr/bin/tini", "--", "node", "platform"]

# Default command can be overridden in docker-compose
CMD ["minMemo", "noBrowser"]