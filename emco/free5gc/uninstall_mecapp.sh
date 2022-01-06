#! /bin/bash

WAIT=5
EMCOCTL=emcoctl


function check_status() {
	itr=0
	echo -n "Instantiating $2 ."
	while true; do
		sleep $WAIT
		stat=$(${EMCOCTL} --config emco-cfg.yaml get $1 | grep "Response Code:" | sed -e 's/Response Code: //')
		echo -n "."
		if [ $stat == "200" ]; then
			out=$(${EMCOCTL} --config emco-cfg.yaml get $1 | grep Response: | sed -e 's/Response: //')
			echo $out | grep "\"status\":\"Instantiated\"" &>> ${LOGFILE}
			if [ $? -eq 0 ]; then
				echo "Done, successful."
				break
			fi
		fi
		itr=$((itr+1))
		if [ $itr -gt $3 ]; then
			echo "Failed. Exiting..."
			exit 2
		fi
	done
}
echo "Removing the MEC App using EMCO..."
${EMCOCTL} --config emco-cfg.yaml delete -f mecapp_deploy.yaml -v mec_values.yaml -w $WAIT
sleep 1
${EMCOCTL} --config emco-cfg.yaml delete -f mecapp_deploy.yaml -v mec_values.yaml

${EMCOCTL} --config emco-cfg.yaml delete -f prio_slice1_deploy.yaml -v mec_values.yaml -w 80
sleep 1
${EMCOCTL} --config emco-cfg.yaml delete -f prio_slice1_deploy.yaml -v mec_values.yaml -w $WAIT
sleep 20

${EMCOCTL} --config emco-cfg.yaml delete -f logical_cloud.yaml -v mec_values.yaml -w $WAIT
sleep 1
${EMCOCTL} --config emco-cfg.yaml delete -f logical_cloud.yaml -v mec_values.yaml -w $WAIT
sleep 10

${EMCOCTL} --config emco-cfg.yaml delete -f mecapp_prereq.yaml -v mec_values.yaml -w $WAIT
${EMCOCTL} --config emco-cfg.yaml delete -f mecapp_prereq.yaml -v mec_values.yaml
echo "-----------------------------------------------------------------------"
echo "-----------------------------------------------------------------------"

