#! /bin/bash

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
containerRegistry=${DOCKER_REPO}
f5gcTag="3.0.5"
cPlaneNode="kube-four"
dPlaneNode="kube-three"
serviceType="LoadBalancer"
Domain="f5gnetslice.com"
upfName="f5gc-upf"
smfName="f5gc-smf"
baseApp="free5g"
subDomain="free5g"

valuesFile=${slice_ns}-mecapp-config-values.yaml
logFile="emco-log-${slice_ns}-mecapp"
scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
emcodir=$(dirname ${scriptDir})
emcoCFGFile=${scriptDir}/emco-cfg.yaml
echo "Log for deploying mec app on ${slice_ns} namespace" > ${logFile}
if [ ${serviceType} == "LoadBalancer" ]; then
	slice_nrf=f5gc-nrf.${slice_ns}.${Domain}
	slice_ausf=f5gc-ausf.${slice_ns}.${Domain}
	slice_udr=f5gc-udr.${slice_ns}.${Domain}
	slice_udm=f5gc-udm.${slice_ns}.${Domain}
	slice_pcf=f5gc-pcf.${slice_ns}.${Domain}
	slice_smf=f5gc-smf.${slice_ns}.${Domain}
	mongo_url=f5gc-mongodb.slice.${Domain}
	mongo_port=27017
elif [ ${serviceType} == "NodePort" ]; then
	slice_nrf=${cPlaneNode}
	slice_ausf=${cPlaneNode}
	slice_udr=${cPlaneNode}
	slice_udm=${cPlaneNode}
	slice_pcf=${cPlaneNode}
	slice_smf=${dPlaneNode}
	mongo_url=${cPlaneNode}
	mongo_port=32017
else
	echo "Unknown ServiceType: $serviceType"
fi

udmServicePort="32503"
udrServicePort="32504"
smfServicePort="32505"
pcfServicePort="32507"
ausfServicePort="32508"
NRFPort="32510"

if [ ${slice_ns} == "slice-a" ]; then
	echo "namespace: slice-a"
	upfN3=172.16.34.3
	ueSubNet=172.16.1.0/24
	nssf_sst="1"
	nssf_sd="010203"
	n4NodePort="32705"
elif [ ${slice_ns} == "slice-b" ]; then
	echo "namespace: slice-b"
	upfN3=172.16.34.4
	ueSubNet=172.16.2.0/24
	nssf_sst="2"
	nssf_sd="010203"
	n4NodePort="32706"
	if [ ${serviceType} == "NodePort" ]; then
		udmServicePort="32513"
		udrServicePort="32514"
		smfServicePort="32515"
		pcfServicePort="32517"
		ausfServicePort="32518"
		NRFPort="32520"
	fi
else
	echo "Only two slices on ns slice-a and slice-b supported"
fi


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
            label: LabelA
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


