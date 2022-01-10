#! /bin/bash

WAIT=5
EMCOCTL=emcoctl
action="none"

if [ -n ${hostIP} ]; then
	hostIP=$(hostname -I | cut -f 1 -d " ")
fi


# generate_emco_cfg : Generates the EMCO config file
# takes two arguments
# $1: HostIP
# $2: FileName (emco-cfg.yaml)
function generate_emco_cfg () {
	cat << NET > ${2}
orchestrator:
  host: $1
  port: 30415
clm:
  host: $1
  port: 30461
ncm:
  host: $1
  port: 30431
ovnaction:
  host: $1
  port: 30471
dcm:
  host: $1
  port: 30477
gac:
  host: $1
  port: 30491
dtc:
  host: $1
  port: 30481
hpaplacement:
  host: $1
  port: 30451
hpaaction:
  host: $1
  port: 30443
NET
}

#tar_charts : Create tar file for charts
# takes 1 argument
# $1 : Charts folder
tar_charts () {
	cd ${1} || { echo "Failed to cd to charts folder"; exit 2; }
	for i in $(ls -d */); do tar -czvf ${i%%/}.tgz ${i%%/} &> /dev/null; done
	cd -
}

# check_status : Check status of EMCO deployment (logical cloud, composite app etc.,)
function check_status() {
	emcoCFG=$1
	logFILE=$2
	URL=$3
	MSG=$4
        CNT=$5
	itr=0
	echo -n "Instantiating ${MSG} ."
	while true; do
		sleep 3
		stat=$(${EMCOCTL} --config ${emcoCFG} get ${URL} | grep "Response Code:" | sed -e 's/Response Code: //')
		echo -n "."
		if [ $stat == "200" ]; then
			out=$(${EMCOCTL} --config ${emcoCFG} get ${URL} | grep Response: | sed -e 's/Response: //')
			echo $out | grep "\"status\":\"Instantiated\"" &>> ${logFILE}
			if [ $? -eq 0 ]; then
				echo "Done, successful."
				break
			fi
		fi
		itr=$((itr+1))
		if [ $itr -gt ${CNT} ]; then
			echo "Failed. Exiting..."
			exit 2
		fi
	done
}


