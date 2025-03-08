FROM asciidoctor/docker-asciidoctor:1.82

RUN apk add --upgrade nodejs npm
RUN npm install -g mathjax-node
ENV NODE_PATH=/usr/local/lib/node_modules

# --- Install diff-pdf ---
WORKDIR /usr/src
RUN apk update
RUN apk add --no-cache --verbose \
    build-base \
    autoconf \
    automake \
    libtool \
    wget \
    poppler-dev \
    wxwidgets-dev \
    cairo-dev \
    wxwidgets \
    poppler \
    cairo \
    xvfb \
    xvfb-run \
    && rm -rf /var/cache/apk/*

RUN wget https://github.com/vslavik/diff-pdf/archive/refs/tags/v0.5.2.tar.gz -O diff-pdf-0.5.2.tar.gz \
    && tar -xzf diff-pdf-0.5.2.tar.gz \
    && rm diff-pdf-0.5.2.tar.gz

WORKDIR /usr/src/diff-pdf-0.5.2
RUN ./bootstrap \
    && ./configure \
    && make \
    && make install

RUN echo "Checking PATH:" && echo $PATH \
    && echo "Checking diff-pdf:" && ls -l /usr/local/bin/diff-pdf || echo "diff-pdf not found" \
    && echo "Checking xvfb-run:" && which xvfb-run || echo "xvfb-run not found" \
    && echo "Testing diff-pdf:" && /usr/local/bin/diff-pdf --version || echo "diff-pdf failed" \
    && echo "Testing with xvfb-run:" && xvfb-run /usr/local/bin/diff-pdf --version || echo "xvfb-run failed"
# ---

WORKDIR /test/
ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
