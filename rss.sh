sed -i '/pubdate/,+2d' public/index.xml
sed -i '/generator/,+1d' public/index.xml
sed -i 's/^.*<\/item>/<\/item>/' public/index.xml