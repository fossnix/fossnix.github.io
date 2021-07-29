sed -i -e '/pubdate/,+2d' public/index.xml
sed -i -e '/generator/,+1d' public/index.xml
sed -i 's/^.*<\/item>/<\/item>/g' public/index.xml
