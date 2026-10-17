FROM asciidoctor/docker-asciidoctor:1.82

RUN apk add --upgrade nodejs npm
# Fonts exercised by the acceptance tests, plus MathJax itself.
# mathjax-newcm is installed as a dependency of @mathjax/src.
RUN npm install -g \
      @mathjax/src@4.1.3 \
      @mathjax/mathjax-tex-font@4.1.3 \
      @mathjax/mathjax-stix2-font@4.1.3 \
      @mathjax/mathjax-asana-font@4.1.3 \
      @mathjax/mathjax-modern-font@4.1.3 \
      @mathjax/mathjax-pagella-font@4.1.3 \
      @mathjax/mathjax-termes-font@4.1.3 \
      @mathjax/mathjax-euler-font-extension@4.1.3
ENV NODE_PATH=/usr/local/lib/node_modules

ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
