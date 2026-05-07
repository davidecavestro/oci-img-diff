FROM node:lts-slim

RUN apt-get update && apt-get install -y \
    curl diffutils findutils jq python3 python3-pip \
    && curl -L https://github.com/regclient/regclient/releases/latest/download/regctl-linux-amd64 > /usr/local/bin/regctl \
    && chmod +x /usr/local/bin/regctl \
    && curl -L https://github.com/Wilfred/difftastic/releases/latest/download/difft-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C /usr/local/bin \
    # Install ansi2html via pip
    && pip3 install ansi2html --break-system-packages \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g diff2html-cli
WORKDIR /app
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
USER root
ENTRYPOINT ["./entrypoint.sh"]