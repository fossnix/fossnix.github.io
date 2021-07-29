sed -i '/pubdate/,+2d/g' public/index.xml
sed -i '/generator/,+1d/' public/index.xml
sed -i 's/^.*<\/item>/<\/item>/g' public/index.xml
