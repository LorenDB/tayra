outdated=$(pip list -o)
echo -n "$outdated"
return_code=$(echo -n "$outdated" | wc -l)
exit $return_code
