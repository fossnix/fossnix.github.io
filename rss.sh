sed -i -e '/pubdate/,+2d' public/index.xml
sed -i -e '/generator/,+1d' public/index.xml
sed -i 's/^.*<\/item>/<\/item>/g' public/index.xml
sed -i '/org-div-home-and-up/,+3d' public/index.html
sed -i "s/<title>Blog Index/<title>FOSSNix's Blog/g" public/index.html
