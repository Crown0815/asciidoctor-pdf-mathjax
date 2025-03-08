FROM asciidoctor/docker-asciidoctor:1.82

# --- Special dependencies required for asciidoctor mathjax
RUN apk add --upgrade nodejs npm
RUN npm install -g mathjax-node
ENV NODE_PATH=/usr/local/lib/node_modules

# ---

WORKDIR /test/
ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
