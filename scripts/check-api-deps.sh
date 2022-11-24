#!/usr/bin/env bash

outdated=$(pip list -o)
echo -n "$outdated"
exit "$(echo -n "$outdated" | wc -l)"
