#! /bin/bash

WAIT=5
LOGFILE="emco_log_output"
EMCOCTL=emcoctl

projName="proj4"
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
ExternalServerIP="192.168.100.100" #Update this value properly, this is used for creating external DNS entry.
emcodir=$(dirname $PWD)

cd ../../Charts || { echo "Failed to cd to charts folder"; exit 2; }
for i in $(ls -d */); do tar -czvf ${i%%/}.tgz ${i%%/} &> /dev/null; done
cd -
if [ ${serviceType} == "LoadBalancer" ]; then
	slice1_nrf=f5gc-nrf.${slice1_ns}.${Domain}
	slice0_nrf=f5gc-nrf.${slice0_ns}.${Domain}
	slice0_ausf=f5gc-ausf.${slice0_ns}.${Domain}
	slice0_udr=f5gc-udr.${slice0_ns}.${Domain}
	slice0_udm=f5gc-udm.${slice0_ns}.${Domain}
	slice0_nssf=f5gc-nssf.slice.${Domain}
	slice0_pcf=f5gc-pcf.${slice0_ns}.${Domain}
	slice0_amf=f5gc-amf.slice.${Domain}
	slice0_smf=f5gc-smf.${slice0_ns}.${Domain}
	mongo_url=f5gc-mongodb.slice.${Domain}
	mongo_port=27017
elif [ ${serviceType} == "NodePort" ]; then
	slice1_nrf=${cPlaneNode}
	slice0_nrf=${cPlaneNode}
	slice0_ausf=${cPlaneNode}
	slice0_udr=${cPlaneNode}
	slice0_udm=${cPlaneNode}
	slice0_nssf=${cPlaneNode}
	slice0_pcf=${cPlaneNode}
	slice0_amf=${dPlaneNode}
	slice0_smf=${dPlaneNode}
	mongo_url=${cPlaneNode}
	mongo_port=32017
else
	echo "Unknown ServiceType: $serviceType"
fi

cat << NET > externalDNSentry.yaml
kind: Service
apiVersion: v1
metadata:
  name: cdn-external-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: www.cdn.f5gnetslice.com
spec:
  type: ExternalName
  externalName: ${ExternalServerIP}
NET

cat << NET > values.yaml
f5gcHelmProf: ${emcodir}/free5gc/profile
monHelmSrc: ${emcodir}/monitor
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

ClusterMonLabel: edge-emco
CompositeAppMonitor: ${compAppName}-monitor
CompositeMonProfile: ${compProfName}-monitor
DeploymentMonIntent: ${depIntGroup}-monitor
GenericMonPlacementIntent: monitorGapPlacement
AppMonitor: monitor
HelmAppMonitor: monitor.tar.gz
monRegistryPrefix: ${containerRegistry}

CompositeCertAppName: ${compAppName}-cert
CertDepIntGrpName: ${depIntGroup}-cert
CompCertProfileName: ${compProfName}-cert
HelmAppCert: cert-manager.tgz

CompositeSdewanAppName: ${compAppName}-sdewan-crd
SdewanDepIntGrpName: ${depIntGroup}-sdewan-crd
CompSdewanProfileName: ${compProfName}-sdewan-crd
HelmAppSdewan: sdewan_controllers.tgz
SdewanCRDImage: integratedcloudnative/sdewan-controller:0.4.1

Compositef5gcSubAppName: ${compAppName}-f5gc-sub
f5gcSubDepIntGrpName: ${depIntGroup}-f5gc-sub
Compf5gcSubProfileName: ${compProfName}-f5gc-sub
HelmAppHttpCrd: http-crd-controller.tgz
HelmAppF5gcSub: f5gc-subscriber.tgz
httpCRDImage: ${containerRegistry}httpcrdcontroller
httpCRDTag: latest

DefaultProfileFw: f5gc-default-pr.tgz

lclouds:
  - name: cert-manager
    namespace: cert-manager
    user: kube-cert
    clusterRef:
      - name: ClusterB-cert-ref
        provider: edgeProvider
        cluster: clusterB
        label: certLabel
      - name: ClusterC-cert-ref
        provider: edgeProvider
        cluster: clusterC
        label: certLabel
  - name: sdewan-manager
    namespace: sdewan-system
    user: kube-sdewan
    clusterRef:
      - name: ClusterB-sdewan-ref
        provider: edgeProvider
        cluster: clusterB
        label: sdewanLabelA
  - name: httpcrd
    namespace: httpcrd-system
    user: kube-httpcrd
    clusterRef:
      - name: ClusterC-httpcrd-ref
        provider: edgeProvider
        cluster: clusterC
        label: httpLabelB
  - name: slice-a
    namespace: ${slice0_ns}
    user: kubeA
    clusterRef:
      - name: ClusterB-sliceA-ref
        provider: edgeProvider
        cluster: clusterB
        label: sliceALabelA
      - name: ClusterC-sliceA-ref
        provider: edgeProvider
        cluster: clusterC
        label: sliceALabelB
  - name: slice
    namespace: slice
    user: kube-slice
    clusterRef:
      - name: ClusterB-sliceC-ref
        provider: edgeProvider
        cluster: clusterB
        label: sliceCLabelA
      - name: ClusterC-sliceC-ref
        provider: edgeProvider
        cluster: clusterC
        label: sliceCLabelB

common:
  - namespace: slice
    compAppName: ${compAppName}-common
    compAppVer: v1
    compProfileName: ${compProfName}-common 
    depIntGrpName: ${depIntGroup}-common
    lCloud: slice
    dependency:
      - app: f5gc-nssf
        depApps:
          - app: f5gc-mongodb
            op: Ready
            wait: 2
      - app: f5gc-amf
        depApps:
          - app: f5gc-mongodb
            op: Ready
            wait: 5
      - app: f5gc-webui
        depApps:
          - app: f5gc-mongodb
            op: Ready
            wait: 5
    ovnNetworks:
      - app: f5gc-amf
        appType: Deployment
        ifName: net2
        nwName: sctpnetwork
        defaultGateway: false
        ipAddress: 172.16.24.3
    dPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceCLabelA
      Apps:
        - name: f5gc-amf
          helmApp: f5gc-amf.tgz
          profileName: amf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_amf}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "mongodb.url": http://${mongo_url}:${mongo_port}
            "image.repository": "${containerRegistry}free5gc-amf"
            "image.tag": ${f5gcTag}
            "helmInstallOvn": "true"
    cPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceCLabelB
      Apps:
        - name: f5gc-mongodb
          helmApp: f5gc-mongodb.tgz
          profileName: mongo-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "service.nodePort": "32017"
        - name: f5gc-nssf
          helmApp: f5gc-nssf.tgz
          profileName: nssf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_nssf}
            "nssaiNrfUri1": http://${slice0_nrf}:${NRFPort}
            "nssaiNrfUri2": http://${slice0_nrf}:${NRFPort}
            "nssaiNrfUri3": http://${slice0_nrf}:${NRFPort}
            "nssaiNrfUri4": http://${slice0_nrf}:${NRFPort}
            "nssaiNrfUri5": http://${slice1_nrf}:${sliceNRFPort}
            "nssaiNrfUri6": http://${slice1_nrf}:${sliceNRFPort}
            "nssaiNrfUri7": http://${slice0_nrf}:${NRFPort}
            "nssaiNrfUri8": http://${slice0_nrf}:${NRFPort}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-nssf"
            "image.tag": ${f5gcTag}
        - name: f5gc-webui
          helmApp: f5gc-webui.tgz
          profileName: webui-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "mongodb.url": mongodb://${mongo_url}:${mongo_port}
            "image.repository": "${containerRegistry}free5gc-webui"
            "image.tag": ${f5gcTag}


slice:
  - namespace: ${slice0_ns}
    compAppName: ${compAppName}
    compAppVer: v1
    compProfileName: ${compProfName} 
    depIntGrpName: ${depIntGroup}
    lCloud: slice-a
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
            wait: 1
      - app: f5gc-pcf
        depApps:
          - app: f5gc-ausf
            op: Ready
            wait: 1
      - app: f5gc-upf
        depApps:
          - app: f5gc-pcf
            op: Ready
            wait: 1
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
        ipAddress: 172.16.34.3 
    dPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceALabelA
      Apps:
        - name: f5gc-upf
          helmApp: f5gc-upf.tgz
          profileName: upf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "baseApp": ${baseApp}
            "hostname": ${upfName}
            "subdomain": ${subDomain}
            "upfcfg.configuration.pfcp[0].addr": ${upfName}.${subDomain}.${slice0_ns}.svc.cluster.local
            "upfcfg.configuration.gtpu[0].addr": 172.16.34.3
            "upfcfg.configuration.dnn_list[0].dnn": internet
            "upfcfg.configuration.dnn_list[0].cidr": 172.16.1.0/24
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
            "pfcp.addr": ${smfName}.${subDomain}.${slice0_ns}.svc.cluster.local
            "userplane_information.up_nodes.gNB1.an_ip": 172.16.34.2
            "userplane_information.up_nodes.UPF.node_id": ${upfName}.${subDomain}.${slice0_ns}.svc.cluster.local
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_smf}
            "n4service.type": "NodePort"
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "mongodb.url": http://${mongo_url}:${mongo_port}
            "image.repository": "${containerRegistry}free5gc-smf"
            "image.tag": ${f5gcTag}
    cPlane:
      clusterProvider: edgeProvider
      clusterLabel: sliceALabelB
      Apps:
        - name: f5gc-nrf
          helmApp: f5gc-nrf.tgz
          profileName: nrf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_nrf}
            "configuration.MongoDBUrl": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-nrf"
            "image.tag": ${f5gcTag}
        - name: f5gc-udr
          helmApp: f5gc-udr.tgz
          profileName: udr-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_udr}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udr"
            "image.tag": ${f5gcTag}
        - name: f5gc-udm
          helmApp: f5gc-udm.tgz
          profileName: udm-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_udm}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-udm"
            "image.tag": ${f5gcTag}
        - name: f5gc-ausf
          helmApp: f5gc-ausf.tgz
          profileName: ausf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_ausf}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-ausf"
            "image.tag": ${f5gcTag}
        - name: f5gc-pcf
          helmApp: f5gc-pcf.tgz
          profileName: pcf-profile
          profileFw: f5gc-default-pr.tgz
          values:
            "service.type": ${serviceType}
            "configuration.sbi.registerIPv4": ${slice0_pcf}
            "configuration.nrfUri": http://${slice0_nrf}:${NRFPort}
            "configuration.mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
            "image.repository": "${containerRegistry}free5gc-pcf"
            "image.tag": ${f5gcTag}

RsyncPort: 30441
GacPort: 30493
OvnPort: 30473
DtcPort: 30483
NpsPort: 30485
SdsPort: 30486
HostIP: 192.168.10.51

NET

function check_status() {
	itr=0
	echo -n "Instantiating $2 ."
	while true; do
		sleep 3
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
echo "Deploying the Free5gc using EMCO..."
${EMCOCTL} --config emco-cfg.yaml apply -f prerequisites.yaml -v values.yaml -w $WAIT &> ${LOGFILE}
echo "-----------------------------------------------------------------------"
sleep 2
#${EMCOCTL} --config emco-cfg.yaml apply -f monitor.yaml -v values.yaml &>> ${LOGFILE}
#check_status "projects/${projName}/composite-apps/${compAppName}-monitor/v1/deployment-intent-groups/${depIntGroup}-monitor/status?type=cluster" "App: emco-monitor" 20
echo "-----------------------------------------------------------------------"
echo "Creating Logical Clouds ..."
${EMCOCTL} --config emco-cfg.yaml apply -f logical_cloud.yaml -v values.yaml -w 2 &>> ${LOGFILE}
sleep 3
check_status "projects/${projName}/logical-clouds/sdewan-manager/status?type=cluster" "Logical Cloud: sdewan-manager" 20
check_status "projects/${projName}/logical-clouds/slice/status?type=cluster" "Logical Cloud: slice" 20
check_status "projects/${projName}/logical-clouds/slice-a/status?type=cluster" "Logical Cloud: slice-a" 20
check_status "projects/${projName}/logical-clouds/cert-manager/status?type=cluster" "Logical Cloud: cert-manager" 20
check_status "projects/${projName}/logical-clouds/httpcrd/status?type=cluster" "Logical Cloud: httpcrd" 20
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f cert-manager-deploy.yaml -v values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-cert/v1/deployment-intent-groups/${depIntGroup}-cert/status?type=cluster" "App: certificate-manager" 20
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f common_deploy.yaml -v values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-common/v1/deployment-intent-groups/${depIntGroup}-common/status?type=cluster" "App: free5gc  common" 120
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f slice_deploy.yaml -v values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}/v1/deployment-intent-groups/${depIntGroup}/status?type=cluster" "App: free5gc  slice_a" 120
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f sdewan-crd-deploy.yaml -v values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-sdewan-crd/v1/deployment-intent-groups/${depIntGroup}-sdewan-crd/status?type=cluster" "App: sdewan-crd-controller" 20
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f f5gc-subscribe.yaml -v values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-f5gc-sub/v1/deployment-intent-groups/${depIntGroup}-f5gc-sub/status?type=cluster" "App: f5gc-subscriber-controller" 20
