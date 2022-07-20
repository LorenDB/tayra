#!/usr/bin/env -S bash -eux

cd "$(dirname $0)/.." # change into base directory

find node_modules/fomantic-ui-css/components -name "*.min.css" -delete
mkdir -p node_modules/fomantic-ui-css/tweaked
echo 'Removing google font…'
sed -i '/@import url(/d' node_modules/fomantic-ui-css/components/site.css
echo "Replacing hardcoded values by CSS vars…"
scripts/fix-fomantic-css.py node_modules/fomantic-ui-css node_modules/fomantic-ui-css/tweaked
echo 'Fixing jQuery import…'
sed -i '1s/^/import jQuery from "jquery"\n/' `find node_modules/fomantic-ui-css/ -name '*.js'`