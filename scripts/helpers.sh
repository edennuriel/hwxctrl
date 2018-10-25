#!/usr/bin/env bash
echo "" > .helpers
for i in $(cat ~/hwxctrl/scripts/.ordered)
do
  echo "alias ${i/.sh}=\"vi $i ; source $i\"" >> .helpers
done
source .helpers
