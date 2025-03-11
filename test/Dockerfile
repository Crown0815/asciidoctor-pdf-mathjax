FROM asciidoctor/docker-asciidoctor:1.82

RUN apk add --upgrade nodejs npm
RUN npm install -g mathjax-node
ENV NODE_PATH=/usr/local/lib/node_modules

ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
