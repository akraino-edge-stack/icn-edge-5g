#! /bin/bash

WAIT=5
LOGFILE="emco_slice_log_output"
EMCOCTL=emcoctl

projName="proj5"
compAppName="compositefree5gc"
compProfName="free5gc-profile"
depIntGroup="free5gc-deployment-intent-group"
containerRegistry=${DOCKER_REPO}
f5gcTag="3.0.5"
cPlaneNode="kube-four"
dPlaneNode="kube-three"
slice0_ns="slice-a"
slice1_ns="slice-b"
serviceType="LoadBalancer"
Domain="f5gnetslice.com"
upfName="f5gc-upf"
smfName="f5gc-smf"
baseApp="free5g"
subDomain="free5g"
NRFPort="32510"
sliceNRFPort="32511"
emcodir=$(dirname $PWD)


#compAppName="compositemecapp"
#compProfName="mec-profile"
#depIntGroup="mec-deployment-intent-group"

if [ ${serviceType} == "LoadBalancer" ]; then
	slice1_nrf=f5gc-nrf.${slice1_ns}.${Domain}
	slice1_ausf=f5gc-ausf.${slice1_ns}.${Domain}
	slice1_udr=f5gc-udr.${slice1_ns}.${Domain}
	slice1_udm=f5gc-udm.${slice1_ns}.${Domain}
	slice1_pcf=f5gc-pcf.${slice1_ns}.${Domain}
	slice1_smf=f5gc-smf.${slice1_ns}.${Domain}
	mongo_url=f5gc-mongodb.slice.${Domain}
	mongo_port=27017
elif [ ${serviceType} == "NodePort" ]; then
	slice1_nrf=${cPlaneNode}
	slice1_ausf=${cPlaneNode}
	slice1_udr=${cPlaneNode}
	slice1_udm=${cPlaneNode}
	slice1_pcf=${cPlaneNode}
	slice1_smf=${dPlaneNode}
	mongo_url=${cPlaneNode}
	mongo_port=32017
else
	echo "Unknown ServiceType: $serviceType"
fi

cat << NET > trafficsteering.yaml
apiVersion: batch.sdewan.akraino.org/v1alpha1
kind: CNFLocalService
metadata:
  name: nat-steer-${slice1_ns}
  namespace: ${slice1_ns}
  labels:
    sdewanPurpose: sdewan-safe-${slice1_ns}

spec:
  localservice: demo-nginx-rtmp.${slice1_ns}.${Domain}
  remoteservice: www.cdn.${Domain}
NET

cat << NET > mec_values.yaml
f5gcHelmProf: ${emcodir}/free5gc/profile
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
Kube1Config: /opt/emco/kube2config
Kube2Config: /opt/emco/kube4config

AdminCloud: admin
sliceCloud: prioslice
certCloud: cert-manager
sdewanCloud: sdewan-manager
httpcrdCloud: httpcrd


DefaultProfileFw: f5gc-default-pr.tgz

lclouds:
  - name: slice-b
    namespace: ${slice1_ns}
    user: kube
    clusterRef:
      - name: ClusterB-slice-ref
        provider: edgeProvider
        cluster: clusterB
        label: sliceLabelA
      - name: ClusterC-slice-ref
        provider: edgeProvider
        cluster: clusterC
        label: sliceLabelB

prioslice:
  - namespace: ${slice1_ns}
    compAppName: ${compAppName}-slice
    compAppVer: v1
    compProfileName: ${compProfName}-slice
    depIntGrpName: ${depIntGroup}-slice
    lCloud: slice-b
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
        ipAddress: 172.16.34.4 
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
            "upfcfg.configuration.pfcp[0].addr": ${upfName}.${subDomain}.${slice1_ns}.svc.cluster.local
            "upfcfg.configuration.gtpu[0].addr": 172.16.34.4
            "upfcfg.configuration.dnn_list[0].dnn": internet
            "upfcfg.configuration.dnn_list[0].cidr": 172.16.2.0/24
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
            "pfcp.addr": ${smfName}.${subDomain}.${slice1_ns}.svc.cluster.local
            "userplane_information.up_nodes.gNB1.an_ip": 172.16.34.2
            "userplane_information.up_nodes.UPF.node_id": ${upfName}.${subDomain}.${slice1_ns}.svc.cluster.local
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].sNssai.sst": "2"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].sNssai.sd": "010203"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[0].dnnUpfInfoList[0].dnn": internet
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].sNssai.sst": "2"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].sNssai.sd": "10203"
            "userplane_information.up_nodes.UPF.sNssaiUpfInfos[1].dnnUpfInfoList[0].dnn": internet
            "userplane_information.up_nodes.UPF.interfaces[0].interfaceType": N3
            "userplane_information.up_nodes.UPF.interfaces[0].endpoints[0]": "172.16.34.4"
            "userplane_information.up_nodes.UPF.interfaces[0].networkInstance": internet
            "sNssaiInfos.sNssai.sst": "2"
            "sNssaiInfos.sNssai.dnnInfos.dnn": "internet"
            "sNssaiInfos.sNssai.dnnInfos.ueSubnet": "172.16.2.0/24"
            "service.type": ${serviceType}
            "n4service.type": "NodePort"
            "n4service.nodePort": "32706"
            "service.port": "32505"
            "service.nodePort": "32505"
            "configuration.sbi.registerIPv4": ${slice1_smf}
            "configuration.nrfUri": http://${slice1_nrf}:${sliceNRFPort}
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
            "service.port": "${sliceNRFPort}"
            "service.nodePort": "${sliceNRFPort}"
            "configuration.sbi.registerIPv4": ${slice1_nrf}
            "configuration.MongoDBUrl": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-nrf"
            "image.tag": ${f5gcTag}
        - name: f5gc-udr
          helmApp: f5gc-udr.tgz
          profileName: udr-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "32505"
            "service.nodePort": "32505"
            "configuration.sbi.registerIPv4": ${slice1_udr}
            "configuration.nrfUri": http://${slice1_nrf}:${sliceNRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udr"
            "image.tag": ${f5gcTag}
        - name: f5gc-udm
          helmApp: f5gc-udm.tgz
          profileName: udm-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "32502"
            "service.nodePort": "32502"
            "configuration.sbi.registerIPv4": ${slice1_udm}
            "configuration.nrfUri": http://${slice1_nrf}:${sliceNRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udm"
            "image.tag": ${f5gcTag}
        - name: f5gc-ausf
          helmApp: f5gc-ausf.tgz
          profileName: ausf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "32508"
            "service.nodePort": "32508"
            "configuration.sbi.registerIPv4": ${slice1_ausf}
            "configuration.nrfUri": http://${slice1_nrf}:${sliceNRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-ausf"
            "image.tag": ${f5gcTag}
        - name: f5gc-pcf
          helmApp: f5gc-pcf.tgz
          profileName: pcf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.port": "32590"
            "service.nodePort": "32590"
            "configuration.sbi.registerIPv4": ${slice1_pcf}
            "configuration.nrfUri": http://${slice1_nrf}:${sliceNRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-pcf"
            "image.tag": ${f5gcTag}



mecApp:
  - namespace: ${slice1_ns}
    compAppName: ${compAppName}-mecApp
    compAppVer: v1
    compProfileName: ${compProfName}-mecApp
    depIntGrpName: ${depIntGroup}-mecApp
    lCloud: slice-b
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

HostIP: 192.168.10.51

NET

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
echo "Deploying the MEC App using EMCO..."
${EMCOCTL} --config emco-cfg.yaml apply -f mecapp_prereq.yaml -v mec_values.yaml -w $WAIT &> ${LOGFILE}
echo "-----------------------------------------------------------------------"
sleep 3
echo "Creating Logical Clouds ..."
${EMCOCTL} --config emco-cfg.yaml apply -f logical_cloud.yaml -v mec_values.yaml &>> ${LOGFILE}
sleep 5
check_status "projects/${projName}/logical-clouds/slice-b/status?type=cluster" "Logical Cloud: slice-b" 20
echo "-----------------------------------------------------------------------"
echo "Deploying a new slice ..."
${EMCOCTL} --config emco-cfg.yaml apply -f prio_slice1_deploy.yaml -v mec_values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-slice/v1/deployment-intent-groups/${depIntGroup}-slice/status?type=cluster" "App: free5gc prio slice_1" 120
echo "-----------------------------------------------------------------------"
#read  -n 1 -p "Press a key to deploy MEC Application and traffic redirection:" input
echo "Deploying mecApp and Installing Traffic Steering Rules ..."
${EMCOCTL} --config emco-cfg.yaml apply -f mecapp_deploy.yaml -v mec_values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-mecApp/v1/deployment-intent-groups/${depIntGroup}-mecApp/status?type=cluster" "App: MEC App slice_1 with Traffic steering Rules" 120
echo "-----------------------------------------------------------------------"

