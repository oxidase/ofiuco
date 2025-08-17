FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update and install core packages
RUN --mount=type=cache,target=/var/lib/apt,id=$CACHE_ID/var/lib/apt \
    --mount=type=cache,target=/var/cache/apt,id=$CACHE_ID/var/cache/apt \
    apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    gnupg \
    libpq-dev \
    postgresql \
    postgresql-contrib \
    python3 \
    python3-pip \
    sudo \
    wget \
    unzip

# Install Bazelisk
RUN curl -Lo /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

# Create dev user
ARG USERNAME=ubuntu
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
CMD ["/bin/bash"]
