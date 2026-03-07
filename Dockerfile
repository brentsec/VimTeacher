FROM debian:bookworm-slim

ARG NEOVIM_VERSION=v0.11.6

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

# Install Neovim stable
RUN curl -LO "https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
    && tar -C /opt -xzf nvim-linux-x86_64.tar.gz \
    && ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
    && rm nvim-linux-x86_64.tar.gz

WORKDIR /plugin

COPY . /plugin/

# Install as Neovim plugin
RUN mkdir -p /root/.local/share/nvim/site/pack/plugins/start/ \
    && ln -s /plugin /root/.local/share/nvim/site/pack/plugins/start/vim-teacher

# Run tests
CMD ["bash", "scripts/test.sh"]
