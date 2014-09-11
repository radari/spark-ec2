#!/bin/bash

pushd /root

if [ -d "spark" ]; then
  echo "Spark seems to be installed. Exiting."
  return
fi

git clone https://github.com/rxin/spark.git -b sort-benchmark spark
cd spark
sbt/sbt assembly/assembly
cd ..

popd
