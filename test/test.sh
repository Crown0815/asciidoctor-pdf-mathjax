IMAGE_TAG='asciidoctor_conversion_image'

cd ../asciidoctor-mathjax || exit
gem build asciidoctor-mathjax.gemspec
mv asciidoctor-mathjax-*.gem ../test/asciidoctor-mathjax-test.gem

cd ../test || exit
docker build --quiet --tag $IMAGE_TAG .
docker run --rm -it -v "$PWD/:/test" $IMAGE_TAG ./test-convert-to-pdf.sh ./test-files/input.adoc
