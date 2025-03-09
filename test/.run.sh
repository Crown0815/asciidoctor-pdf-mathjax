IMAGE_TAG='asciidoctor_conversion_image'

cd .. || exit
gem build asciidoctor-pdf-mathjax.gemspec || exit
mv asciidoctor-pdf-mathjax-*.gem ./test/asciidoctor-pdf-mathjax-test.gem || exit

cd ./test || exit
docker build --tag $IMAGE_TAG .
docker run --rm -v "$PWD/:/test" $IMAGE_TAG ./verify.sh /test/verification
