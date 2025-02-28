FROM asciidoctor/docker-asciidoctor:1.82
RUN apk add --upgrade nodejs npm

# This gem improves conversion performance. source: https://asciidoctor.zulipchat.com/#narrow/stream/288690-users.2Fasciidoctor-pdf/topic/Out.20of.20memory.20when.20converting.20multiple.20files.20using.20docker/near/409161765
RUN apk add graphicsmagick-dev ruby-dev musl-dev gcc
# Update npm and install mathjax-node, verify installation
RUN npm install -g npm && npm install -g mathjax-node && npm list -g mathjax-node || echo "Failed to install mathjax-node"
ENV NODE_PATH=/usr/local/lib/node_modules
RUN node -e "require('mathjax-node')" || echo "Failed to require mathjax-node"

RUN gem install nokogiri
WORKDIR /test/
ENTRYPOINT ["bash", "-c", "exec \"$@\"", "--"]
