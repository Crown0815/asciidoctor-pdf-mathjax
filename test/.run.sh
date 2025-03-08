IMAGE_TAG='asciidoctor_conversion_image'

cd .. || exit
gem build asciidoctor-mathjax.gemspec
mv asciidoctor-mathjax-*.gem ./test/asciidoctor-mathjax-test.gem

cd ./test || exit
docker build --tag $IMAGE_TAG .
docker run --rm -v "$PWD/:/test" $IMAGE_TAG ./verify.sh asciimath latex stem_asciimath stem_latex
