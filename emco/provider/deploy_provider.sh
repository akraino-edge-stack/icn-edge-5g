#! /bin/bash

WAIT=5
LOGFILE="emco_providerlog_output"
EMCOCTL=emcoctl

projName="provider-proj"
compAppName="compositeprovider"
compProfName="provider-profile"
depIntGroup="provider-intent-group"
containerRegistry=${DOCKER_REPO}
cPlaneNode="kube-four"
dPlaneNode="kube-three"
emcodir=$(dirname ${PWD})

cd ${emcodir}/../Charts || { echo "Failed to cd to charts folder"; exit 2; }
for i in $(ls -d */); do tar -czvf ${i%%/}.tgz ${i%%/} &> /dev/null; done
cd -


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

cat << NET > provider_values.yaml
f5gcHelmProf: ${emcodir}/free5gc/profile
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
monRegistryPrefix: ${containerRegistry}

CompositeProviderAppName: ${compAppName}-provider
ProviderDepIntGrpName: ${depIntGroup}-provider
CompProviderProfileName: ${compProfName}-provider
HelmAppDNS: external-dns.tgz
HelmAppMetal: metallb.tgz


DefaultProfileFw: f5gc-default-pr.tgz


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
echo "Deploying the Provider using EMCO..."
${EMCOCTL} --config emco-cfg.yaml apply -f prerequisites.yaml -v provider_values.yaml -w $WAIT &> ${LOGFILE}
echo "-----------------------------------------------------------------------"
sleep 2
${EMCOCTL} --config emco-cfg.yaml apply -f monitor.yaml -v provider_values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-monitor/v1/deployment-intent-groups/${depIntGroup}-monitor/status?type=cluster" "App: emco-monitor" 30
echo "-----------------------------------------------------------------------"
${EMCOCTL} --config emco-cfg.yaml apply -f deploy_provider.yaml -v provider_values.yaml &>> ${LOGFILE}
check_status "projects/${projName}/composite-apps/${compAppName}-provider/v1/deployment-intent-groups/${depIntGroup}-provider/status?type=cluster" "App: provider" 20
echo "-----------------------------------------------------------------------"

