FROM node:18-alpine

# Use a non-root user with a specific UID/GID
ARG USER_ID=1001
ARG GROUP_ID=1001
ARG GITHUB_REPO=https://github.com/Superalgos/Superalgos.git
ARG BRANCH=master

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache --virtual .build-deps \
    make \
    g++ \
    unzip \
    bash \
    curl \
    git \
    && apk add --no-cache \
    python3 \
    tzdata

# Clone the repository instead of copying local files
RUN git clone --depth 1 --branch ${BRANCH} ${GITHUB_REPO} . \
    && npm ci --omit=optional \
    && chmod +x ./Docker/download-plugins.sh \
    && ./Docker/download-plugins.sh

# Create required directories with correct permissions
RUN mkdir -p \
    ./Platform/My-Data-Storage \
    ./Platform/My-Log-Files/Platform \
    ./Platform/My-Workspaces \
    ./Platform/My-Network-Nodes-Data \
    ./Platform/My-Social-Trading-Data \
    ./Platform/My-Secrets

# Create group and user with specific UID/GID
RUN addgroup -g ${GROUP_ID} superalgos \
    && adduser -u ${USER_ID} -G superalgos -D -H superalgos

# Set ownership and permissions
RUN chown -R ${USER_ID}:${GROUP_ID} /app \
    && chmod -R 775 /app \
    && apk del .build-deps

# Switch to non-root user
USER superalgos

# Expose ports for Superalgos services
EXPOSE 34248 18041 18043

# Define volumes for persistent data
VOLUME ["/app/Platform/My-Data-Storage", \
       "/app/Platform/My-Log-Files", \
       "/app/Platform/My-Workspaces", \
       "/app/Platform/My-Network-Nodes-Data", \
       "/app/Platform/My-Social-Trading-Data", \
       "/app/Platform/My-Secrets"]

# Set environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS=--max_old_space_size=8192 \
    PM2_HOME=/tmp/.pm2

# Healthcheck to verify the application is running properly
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -q --spider http://localhost:34248/health || exit 1

# Entrypoint script
ENTRYPOINT ["node", "platform"]

# Default command can be overridden in docker-compose
CMD ["minMemo", "noBrowser"]