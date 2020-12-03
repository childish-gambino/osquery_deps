#!/bin/bash

down_dir=$(mktemp -d) && cd  ${down_dir}
echo $PWD
curl -OL https://raw.githubusercontent.com/childish-gambino/osquery_deps/master/sdeploy.sh
source ${PWD}/sdeploy.sh
