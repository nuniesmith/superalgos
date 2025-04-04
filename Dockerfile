FROM node:16-alpine
# Use a non-root user with a specific UID/GID
ARG USER_ID=1001
ARG GROUP_ID=1001

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

# Copy only necessary files to leverage Docker cache
COPY package*.json ./
COPY Docker/download-plugins.sh ./Docker/

# Install dependencies
RUN npm ci --omit=optional \
    && chmod +x ./Docker/download-plugins.sh \
    && ./Docker/download-plugins.sh

# Copy the rest of the application
COPY . .

# Create required directories with correct permissions
RUN mkdir -p \
    ./Platform/My-Data-Storage \
    ./Platform/My-Log-Files \
    ./Platform/My-Workspaces \
    ./Platform/My-Network-Nodes-Data \
    ./Platform/My-Social-Trading-Data

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
        "/app/Platform/My-Social-Trading-Data"]

# Set environment variables
ENV NODE_ENV=production \
    NODE_OPTIONS=--max_old_space_size=4096 \
    PM2_HOME=/tmp/.pm2

# Entrypoint with additional options for headless and minimal memory
ENTRYPOINT ["node", "platform", "minMemo", "noBrowser"]