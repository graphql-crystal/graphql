ARG VARIANT="bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

RUN curl -fsSL https://crystal-lang.org/install.sh | bash \
  && wget https://github.com/elbywan/crystalline/releases/latest/download/crystalline_x86_64-unknown-linux-gnu.gz -O crystalline.gz \
  && gzip -d crystalline.gz && chmod +x crystalline && mv crystalline /usr/local/bin/crystalline