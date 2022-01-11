#! /bin/bash

source common_helper.sh

slice_ns="dummy"
configFile="dummy"

#options
if ! options=$(getopt -o f:n: -l configfile:,namespace: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
eval set -- $options
while [ $# -gt 0 ]
do
    case $1 in
    -n|--namespace) slice_ns="$2" ; shift;;
    -f|--configfile) configFile="$2" ; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
    esac
    shift
done

action=$1
source ${configFile}

projName="proj5-${slice_ns}"
compAppName="compositefree5gc-${slice_ns}"
compProfName="free5gc-${slice_ns}-profile"
depIntGroup="free5gc-${slice_ns}-deployment-intent-group"
containerRegistry=${DOCKER_REPO}
f5gcTag="3.0.5"
cPlaneNode="kube-four"
dPlaneNode="kube-three"
#serviceType="LoadBalancer"
Domain="f5gnetslice.com"
upfName="f5gc-upf"
smfName="f5gc-smf"
baseApp="free5g"
subDomain="free5g"

valuesFile=${slice_ns}-config-values.yaml
logFile="emco-log-${slice_ns}"
scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
emcodir=$(dirname ${scriptDir})
emcoCFGFile=${scriptDir}/emco-cfg.yaml

echo "Log for deploying slice on ${slice_ns} namespace" > ${logFile}
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
	exit 3
fi

if [ ${slice_ns} == "slice-a" ]; then
	echo "namespace: slice-a"
elif [ ${slice_ns} == "slice-b" ]; then
	echo "namespace: slice-b"
else
	echo "Only two slices on ns slice-a and slice-b supported"
	exit 3
fi


create_slice_values () {
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

lclouds:
  - name: ${slice_ns}
    namespace: ${slice_ns}
    user: kube-${slice_ns}
    clusterRef:
      - name: ClusterB-${slice_ns}-ref
        provider: edgeProvider
        cluster: clusterB
        label: sliceLabelA
      - name: ClusterC-${slice_ns}-ref
        provider: edgeProvider
        cluster: clusterC
        label: sliceLabelB

prioslice:
  - namespace: ${slice_ns}
    compAppName: ${compAppName}
    compAppVer: v1
    compProfileName: ${compProfName}
    depIntGrpName: ${depIntGroup}
    lCloud: ${slice_ns}
    dependency:
      - app: f5gc-udr
        depApps:
          - app: f5gc-nrf
            op: Ready
            wait: 2
      - app: f5gc-udm
        depApps:
          - app: f5gc-udr
            op: Ready
            wait: 2 
      - app: f5gc-ausf
        depApps:
          - app: f5gc-udm
            op: Ready
            wait: 2
      - app: f5gc-pcf
        depApps:
          - app: f5gc-ausf
            op: Ready
            wait: 2
      - app: f5gc-upf
        depApps:
          - app: f5gc-pcf
            op: Ready
            wait: 2
      - app: f5gc-smf
        depApps:
          - app: f5gc-upf
            op: Ready
            wait: 5
    ovnNetworks:
      - app: f5gc-upf
        appType: Deployment
        ifName: net2
        nwName: gtpunetwork
        defaultGateway: false
        ipAddress: ${upfN3}
    dPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceLabelA
      Apps:
        - name: f5gc-upf
          helmApp: f5gc-upf.tgz
          profileName: upf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "baseApp": ${baseApp}
            "hostname": ${upfName}
            "subdomain": ${subDomain}
            "upfcfg.configuration.pfcp[0].addr": ${upfName}.${subDomain}.${slice_ns}.svc.cluster.local
            "upfcfg.configuration.gtpu[0].addr": ${upfN3}
            "upfcfg.configuration.dnn_list[0].dnn": internet
            "upfcfg.configuration.dnn_list[0].cidr": ${ueSubNet}
            "image.repository": "${containerRegistry}free5gc-upf"
            "image.tag": ${f5gcTag}
            "sdewan.image": integratedcloudnative/sdewan-cnf:0.4.1
            "helmInstallOvn": "true"
        - name: f5gc-smf
          helmApp: f5gc-smf.tgz
          profileName: smf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "baseApp": ${baseApp}
            "hostname": ${smfName}
            "subdomain": ${subDomain}
            "pfcp.addr": ${smfName}.${subDomain}.${slice_ns}.svc.cluster.local
            "userplane_information.up_nodes.gNB1.an_ip": 172.16.34.2
            "userplane_information.up_nodes.UPF.node_id": ${upfName}.${subDomain}.${slice_ns}.svc.cluster.local
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].sNssai.sst": "${nssf_sst}"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].sNssai.sd": "${nssf_sd}"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].dnnUpfInfoList[0].dnn": internet
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].sNssai.sst": "${nssf_sst}"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].sNssai.sd": "${nssf_sd}"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].dnnUpfInfoList[0].dnn": internet
            "userplane_information.up_nodes.UPF.interfaces[0].interfaceType": N3
            "userplane_information.up_nodes.UPF.interfaces[0].endpoints[0]": "${upfN3}"
            "userplane_information.up_nodes.UPF.interfaces[0].networkInstance": internet
            "sNssaiInfos.sNssai.sst": "${nssf_sst}"
            "sNssaiInfos.sNssai.dnnInfos.dnn": "internet"
            "sNssaiInfos.sNssai.dnnInfos.ueSubnet": "${ueSubNet}"
            "service.type": ${serviceType}
            "n4service.type": "NodePort"
            "n4service.nodePort": "${n4NodePort}"
            "service.port": "${smfServicePort}"
            "service.nodePort": "${smfServicePort}"
            "configuration.sbi.registerIPv4": ${slice_smf}
            "configuration.nrfUri": http://${slice_nrf}:${NRFPort}
            "mongodb.url": http://${mongo_url}:${mongo_port}
            "image.repository": "${containerRegistry}free5gc-smf"
            "image.tag": ${f5gcTag}
    cPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceLabelB
      Apps:
        - name: f5gc-nrf
          helmApp: f5gc-nrf.tgz
          profileName: nrf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "${NRFPort}"
            "service.nodePort": "${NRFPort}"
            "configuration.sbi.registerIPv4": ${slice_nrf}
            "configuration.MongoDBUrl": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-nrf"
            "image.tag": ${f5gcTag}
        - name: f5gc-udr
          helmApp: f5gc-udr.tgz
          profileName: udr-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "${udrServicePort}"
            "service.nodePort": "${udrServicePort}"
            "configuration.sbi.registerIPv4": ${slice_udr}
            "configuration.nrfUri": http://${slice_nrf}:${NRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udr"
            "image.tag": ${f5gcTag}
        - name: f5gc-udm
          helmApp: f5gc-udm.tgz
          profileName: udm-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "${udmServicePort}"
            "service.nodePort": "${udmServicePort}"
            "configuration.sbi.registerIPv4": ${slice_udm}
            "configuration.nrfUri": http://${slice_nrf}:${NRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udm"
            "image.tag": ${f5gcTag}
        - name: f5gc-ausf
          helmApp: f5gc-ausf.tgz
          profileName: ausf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "${ausfServicePort}"
            "service.nodePort": "${ausfServicePort}"
            "configuration.sbi.registerIPv4": ${slice_ausf}
            "configuration.nrfUri": http://${slice_nrf}:${NRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-ausf"
            "image.tag": ${f5gcTag}
        - name: f5gc-pcf
          helmApp: f5gc-pcf.tgz
          profileName: pcf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "${pcfServicePort}"
            "service.nodePort": "${pcfServicePort}"
            "configuration.sbi.registerIPv4": ${slice_pcf}
            "configuration.nrfUri": http://${slice_nrf}:${NRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-pcf"
            "image.tag": ${f5gcTag}

NET

}

deploy_slice_app () {
	echo "Deploying the Slice NFs using EMCO..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/slice_common_prerequisites.yaml -v ${valuesFile} -w $WAIT &>> ${logFile}
	echo "-----------------------------------------------------------------------"
	echo "Creating Logical Cloud ${slice_ns} ..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/logical_cloud.yaml -v ${valuesFile} &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/logical-clouds/${slice_ns}/status?type=cluster" "Logical Cloud: ${slice_ns}" 20
	echo "-----------------------------------------------------------------------"
	echo "Deploying a new slice on namespace ${slice_ns}..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${scriptDir}/prio_slice1_deploy.yaml -v ${valuesFile} -w 15 &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}/v1/deployment-intent-groups/${depIntGroup}/status?type=cluster" "App: free5gc prio ${slice_ns}" 120
	echo "-----------------------------------------------------------------------"
}

uninstall_slice_app () {

	${EMCOCTL} --config ${emcoCFGFile} delete -f ${scriptDir}/prio_slice1_deploy.yaml -v ${valuesFile} -w 30
	sleep 20
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${scriptDir}/prio_slice1_deploy.yaml -v ${valuesFile} -w $WAIT
	sleep 2

	${EMCOCTL} --config ${emcoCFGFile} delete -f ${emcodir}/provider/logical_cloud.yaml -v ${valuesFile} -w $WAIT
	sleep 10
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${emcodir}/provider//logical_cloud.yaml -v ${valuesFile} -w $WAIT
	sleep 1

	${EMCOCTL} --config ${emcoCFGFile} delete -f ${emcodir}/provider/slice_common_prerequisites.yaml -v ${valuesFile} -w $WAIT
	echo "-----------------------------------------------------------------------"
}

if [ $action == "install" ]; then
	create_slice_values
	deploy_slice_app
elif [ $action == "uninstall" ]; then
	uninstall_slice_app
else
	echo "unknown action. Allowed: install / uninstall"
fi


