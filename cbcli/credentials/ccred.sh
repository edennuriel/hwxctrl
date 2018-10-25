#!/usr/bin/env bash
for i in `ls *-cred.json`
    do
        echo cb credential create from-file --cli-input-json $i --name ${i/-cred.json}
    done

