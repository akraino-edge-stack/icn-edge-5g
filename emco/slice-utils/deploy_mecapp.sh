#! /bin/bash

source common-config
source common_helper.sh

slice_ns="slice-a"
action="none"

#options
if ! options=$(getopt -o n: -l namespace: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
eval set -- $options
while [ $# -gt 0 ]
do
    case $1 in
    -n|--namespace) slice_ns="$2" ; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

action=$1
projName="proj5-${slice_ns}"
compAppName="compositefree5gc-${slice_ns}"
compProfName="free5gc-${slice_ns}-profile"
depIntGroup="free5gc-${slice_ns}-deployment-intent-group"

valuesFile="${slice_ns}-mecapp-config-values.yaml"
logFile="emco-${slice_ns}-mecapp.log"
scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
emcodir=$(dirname ${scriptDir})
emcoCFGFile=${scriptDir}/emco-cfg.yaml
echo "Log for deploying mec app on ${slice_ns} namespace" > ${logFile}

create_mecapp_values () {
	cat << NET > ${valuesFile}
f5gcHelmProf: ${emcodir}/../profiles
ChartHelmSrc: ${emcodir}/../Charts
f5gcHelmSrc: ${emcodir}/../Charts



ProjectName: ${projName}
ClusterProvider: edgeProvider
Cluster1: clusterB
Cluster2: clusterC
Cluster1Label: edge-clusterB
Cluster2Label: edge-clusterC
Cluster1Ref: clusterB-ref
Cluster2Ref: clusterC-ref

AdminCloud: admin

defaultJson: ${emcodir}/emco-init/default.json
DefaultProfileFw: f5gc-default-pr.tgz

mecApp:
  - namespace: ${slice_ns}
    compAppName: ${compAppName}-mecApp
    compAppVer: v1
    compProfileName: ${compProfName}-mecApp
    depIntGrpName: ${depIntGroup}-mecApp
    lCloud: ${slice_ns}
    Apps:
      - name: demo-nginx-rtmp
        helmApp: demo-nginx-rtmp.tgz
        profileName: nginx-profile
        profileFw: f5gc-default-pr.tgz
        cluster:
          - provider: edgeProvider
            label: sliceLabelA
        values:
          "service.type": ${serviceType}
          "image.repository": "${containerRegistry}demo-nginx-rtmp"
          "image.tag": latest

NET

	cat << NET > trafficsteering.yaml
apiVersion: batch.sdewan.akraino.org/v1alpha1
kind: CNFLocalService
metadata:
  name: nat-steer-${slice_ns}
  namespace: ${slice_ns}
  labels:
    sdewanPurpose: sdewan-safe-${slice_ns}

spec:
  localservice: demo-nginx-rtmp.${slice_ns}.${Domain}
  remoteservice: www.cdn.${Domain}
NET

}


deploy_mecapp () {
	echo "Deploying the MEC App using EMCO..."
	echo "Deploying mecApp and Installing Traffic Steering Rules ..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/demo-mec-app/mecapp_deploy.yaml -v ${valuesFile} &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-mecApp/v1/deployment-intent-groups/${depIntGroup}-mecApp/status?type=cluster" "App: MEC App ${slice_ns} with Traffic steering Rules" 120
		echo "-----------------------------------------------------------------------"
}

uninstall_mecapp () {
	echo "Removing the MEC App using EMCO..."
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${emcodir}/demo-mec-app/mecapp_deploy.yaml -v ${valuesFile} -w $WAIT
	sleep 1
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${emcodir}/demo-mec-app/mecapp_deploy.yaml -v ${valuesFile}
}

if [ $action == "install" ]; then
	create_mecapp_values
	deploy_mecapp
elif [ $action == "uninstall" ]; then
	uninstall_mecapp
else
	echo "unknown action. Allowed: install / uninstall"
fi


