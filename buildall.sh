export ORIGPATH=${PATH}

export PATH=${ORIGPATH}:/home/markw/fpga/altera/13.0sp1/quartus/bin
cd de1
./build.sh ALL
cd ../chameleon
./build.sh ALL
cd ../replay
./build.sh > build.log 2> build.err
cd ../mist
./build.sh ALL
cd ../mcc216
./build.sh ALL
cd ../mcctv
./build.sh ALL
cd ../papilioduo
./build.sh ALL
cd ../mist_5200
./build.sh ALL
cd ../de1_5200
./build.sh ALL
cd ../mcc216_5200
./build.sh ALL
cd ../mcctv_5200
./build.sh ALL


export PATH=${ORIGPATH}:/home/markw/fpga/altera/14.0/quartus/bin:/home/markw/fpga/altera/14.0/quartus/sopc_builder/bin/
cd ../sockit
./build.sh

export PATH=${ORIGPATH}
unset ORIGPATH

