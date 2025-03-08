IMAGE_TAG='asciidoctor_conversion_image'

cd .. || exit
gem build asciidoctor-mathjax.gemspec
mv asciidoctor-mathjax-*.gem ./test/asciidoctor-mathjax-test.gem

cd ./test || exit
docker build --quiet --tag $IMAGE_TAG .
docker run --rm -it -v "$PWD/:/test" $IMAGE_TAG ./convert-to-pdf.sh \
  ./verification/asciimath.adoc \
  ./verification/latex.adoc \
  ./verification/stem_asciimath.adoc \
  ./verification/stem_latex.adoc
