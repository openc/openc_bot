#!/bin/bash

UNPUSHED=$(git log origin/master..HEAD)
if [ "x$UNPUSHED" == "x" ]; then
    gem build openc_bot.gemspec
    gem push $(ls *gem|tail -1)
else
 echo "Unpushed commits!"
fi

function clean {
 rm -f *gem
}
trap clean EXIT
