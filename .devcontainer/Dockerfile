# Use a Python base image
FROM mcr.microsoft.com/devcontainers/python:3.14

# Install Node.js (Version 20) for the Vue.js Frontend and Docker
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get update && apt-get install -y nodejs python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright dependencies for E2E testing
# See: https://playwright.dev/docs/ci#docker
RUN apt-get update && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libxkbcommon0 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# create a venv to ease tooling work
RUN python3 -m venv /home/vscode/opt/venv && \
    chown -R vscode:vscode /home/vscode/opt/venv && \
    /home/vscode/opt/venv/bin/pip install --upgrade pip
ENV PATH="/home/vscode/opt/venv/bin:$PATH"

# Ensure venv is activated by default for all shell sessions
RUN echo 'export PATH="/home/vscode/opt/venv/bin:$PATH"' >> /home/vscode/.bashrc && \
    echo 'export VIRTUAL_ENV=/home/vscode/opt/venv' >> /home/vscode/.bashrc

RUN pip install --upgrade pip

# Install Docker CLI
RUN curl -fsSL https://get.docker.com | sh \
    && usermod -aG docker vscode

# Set the working directory
WORKDIR /workspace

# Install global tools
RUN npm install -g @vue/cli vite

# Ensure the 'vscode' user has ownership of the workspace
RUN chown -R vscode:vscode /workspace
