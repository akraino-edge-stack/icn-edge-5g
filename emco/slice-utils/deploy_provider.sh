#! /bin/bash

source common-config
source common_helper.sh

if [ $# -lt 1 ]; then
	echo "Missing action argument"
	exit 1
else
	action=$1
fi

projName="proj-emco-init"
compAppName="compositeprovider"
compProfName="provider-profile"
depIntGroup="provider-intent-group"

logFile="emco-provider.log"
valuesFile="provider-config-values.yaml"
echo "Log for deploying provider (e-dns and metallb) applications" > ${logFile}

create_provider_values () {
	cat << NET > ${valuesFile}
f5gcHelmProf: ${emcodir}/../profiles
monHelmSrc: ${emcodir}/monitor
ChartHelmSrc: ${emcodir}/../Charts
f5gcHelmSrc: ${emcodir}/../Charts


ProjectName: ${projName}
ClusterProvider: edgeProvider
Cluster1: clusterB
Cluster2: clusterC
ClusterLabel: edge-cluster
Cluster1Label: edge-clusterB
Cluster2Label: edge-clusterC
Cluster1Ref: clusterB-ref
Cluster2Ref: clusterC-ref
Kube1Config: /opt/emco/kube2config
Kube2Config: /opt/emco/kube4config

AdminCloud: admin
nameSpace: default

ClusterMonLabel: edge-emco
CompositeAppMonitor: ${compAppName}-monitor
CompositeMonProfile: ${compProfName}-monitor
DeploymentMonIntent: ${depIntGroup}-monitor
GenericMonPlacementIntent: monitorGapPlacement
AppMonitor: monitor
HelmAppMonitor: monitor.tar.gz
MonitorTag: latest
monRegistryPrefix: ${containerRegistry}

CompositeProviderAppName: ${compAppName}-provider
ProviderDepIntGrpName: ${depIntGroup}-provider
CompProviderProfileName: ${compProfName}-provider
HelmAppDNS: external-dns.tgz
PdnsURL: ${PDNS_URL}
HelmAppMetal: metallb.tgz
metallbProtocol: ${metallbMode}
metallbL2Config: 
  clusterA: |-
    [
      {
        "op": "replace",
        "path": "/data/config",
        "value": "  address-pools:\n  - addresses:\n    - 192.168.20.220-192.168.20.250\n    name: default\n    protocol: layer2\n"
      }
    ]
  clusterB: |-
    [
      {
        "op": "replace",
        "path": "/data/config",
        "value": "  address-pools:\n  - addresses:\n    - 192.168.30.220-192.168.30.250\n    name: default\n    protocol: layer2\n"
      }
    ]
 
metallbL3Config: 
  clusterA: |-
    [
      {
        "op": "replace",
        "path": "/data/config",
        "value": "  peers:\n  - peer-address: 192.168.20.50\n    peer-asn: 3000\n    my-asn: 5000\n  address-pools:\n  - name: default\n    protocol: bgp\n    addresses:\n    - 192.178.20.0/24\n"
      }
    ]
  clusterB: |-
    [
      {
        "op": "replace",
        "path": "/data/config",
        "value": "  peers:\n  - peer-address: 192.168.20.50\n    peer-asn: 3000\n    my-asn: 4000\n  address-pools:\n  - name: default\n    protocol: bgp\n    addresses:\n    - 192.178.10.0/24\n"
      }
    ]

defaultJson: ${defaultJsonFile}
defaultYAML: ${defaultYAMLFile}
DefaultProfileFw: f5gc-default-pr.tgz

RsyncPort: 30431
GacPort: 30433
OvnPort: 30432
DtcPort: 30418
NpsPort: 30485
SdsPort: 30486
HostIP: ${hostIP}

NET
}

deploy_provider_apps () {
	echo "EMCO initializing..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/emco-init/emco-controller.yaml -v ${valuesFile} -w $WAIT &>> ${logFile}
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/prerequisites.yaml -v ${valuesFile} -w $WAIT &>> ${logFile}
	echo "-----------------------------------------------------------------------"
	sleep 2
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/monitor.yaml -v ${valuesFile} &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-monitor/v1/deployment-intent-groups/${depIntGroup}-monitor/status?type=cluster" "App: emco-monitor" 30
	echo "-----------------------------------------------------------------------"

	echo "Deploying the Provider using EMCO..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/deploy_edns_metallb.yaml -v ${valuesFile} &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-provider/v1/deployment-intent-groups/${depIntGroup}-provider/status?type=cluster" "App: provider" 20
	sleep 5
	echo "-----------------------------------------------------------------------"
}

uninstall_provider_apps () {
	emcoctl --config ${emcoCFGFile} delete -f ${emcodir}/provider/deploy_edns_metallb.yaml -v ${valuesFile} -w 10
	emcoctl --config ${emcoCFGFile} delete -f ${emcodir}/provider/monitor.yaml -v ${valuesFile} -w 10
	emcoctl --config ${emcoCFGFile} delete -f ${emcodir}/provider/prerequisites.yaml -v ${valuesFile} -w 10
	emcoctl --config ${emcoCFGFile} delete -f ${emcodir}/emco-init/emco-controller.yaml -v ${valuesFile} -w 10

}

if [ $action == "install" ]; then
	generate_emco_cfg ${hostIP} ${emcoCFGFile}
	tar_charts ${emcodir}/../Charts
	create_provider_values
	deploy_provider_apps
elif [ $action == "uninstall" ]; then
	uninstall_provider_apps
else
	echo "unknown action. Allowed: install / uninstall"
fi

