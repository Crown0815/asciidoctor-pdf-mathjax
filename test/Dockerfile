FROM asciidoctor/docker-asciidoctor:1.82
# This gem improves conversion performance. source: https://asciidoctor.zulipchat.com/#narrow/stream/288690-users.2Fasciidoctor-pdf/topic/Out.20of.20memory.20when.20converting.20multiple.20files.20using.20docker/near/409161765
RUN apk add graphicsmagick-dev ruby-dev musl-dev gcc

# --- Special dependencies required for asciidoctor mathjax
RUN apk add --upgrade nodejs npm
RUN npm install -g mathjax-node
ENV NODE_PATH=/usr/local/lib/node_modules

RUN gem install nokogiri
RUN gem install ttfunk
# ---

WORKDIR /test/
ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
