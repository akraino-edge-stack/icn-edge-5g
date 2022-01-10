#! /bin/bash

source common_helper.sh

if [ $# -lt 1 ]; then
	echo "Missing action argument"
	exit 1
else
	action=$1
fi

projName="proj4"
compAppName="compositefree5gc"
compProfName="free5gc-profile"
depIntGroup="free5gc-deployment-intent-group"
containerRegistry=${DOCKER_REPO}
f5gcTag="3.0.5"
cPlaneNode="kube-four"
dPlaneNode="kube-three"
slice_ns="slice"
slice0_ns="slice-a"
slice1_ns="slice-b"
serviceType="LoadBalancer"
Domain="f5gnetslice.com"
NRFPort="32510"
ExternalServerIP="192.168.100.100" #Update this value properly, this is used for creating external DNS entry.

logFile="emco-log-${slice_ns}-common"
valuesFile=${slice_ns}-common-config-values.yaml
scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
emcodir=$(dirname ${scriptDir})
emcoCFGFile=${scriptDir}/emco-cfg.yaml

echo "Logging the deployment of apps common to all slices" > ${logFile}
if [ ${serviceType} == "LoadBalancer" ]; then
	slice1_nrf=f5gc-nrf.${slice1_ns}.${Domain}
	slice0_nrf=f5gc-nrf.${slice0_ns}.${Domain}
	slice0_ausf=f5gc-ausf.${slice0_ns}.${Domain}
	slice0_udr=f5gc-udr.${slice0_ns}.${Domain}
	slice0_udm=f5gc-udm.${slice0_ns}.${Domain}
	slice0_pcf=f5gc-pcf.${slice0_ns}.${Domain}
	slice0_smf=f5gc-smf.${slice0_ns}.${Domain}
	slice0_nssf=f5gc-nssf.${slice_ns}.${Domain}
	slice0_amf=f5gc-amf.${slice_ns}.${Domain}
	mongo_url=f5gc-mongodb.${slice_ns}.${Domain}
	mongo_port=27017
	sliceNRFPort="32510"
	commonNRF="32510"
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
	sliceNRFPort="32520"
	commonNRF="32530"
else
	echo "Unknown ServiceType: $serviceType"
	exit 3
fi


create_slice_common_values () {

	cat << NET > externalDNSentry.yaml
kind: Service
apiVersion: v1
metadata:
  name: cdn-external-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: www.cdn.${Domain}
spec:
  type: ExternalName
  externalName: ${ExternalServerIP}
NET

	cat << NET > ${valuesFile}
f5gcHelmProf: ${emcodir}/../profiles
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

defaultJson: ${emcodir}/emco-init/default.json
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
  - name: ${slice_ns}-common
    namespace: ${slice_ns}
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
  - namespace: cert-manager
    compAppName: ${compAppName}-cert
    compAppVer: v1
    compProfileName: ${compProfName}-cert
    depIntGrpName: ${depIntGroup}-cert
    lCloud: cert-manager
    Apps:
      - name: cert-manager
        helmApp: cert-manager.tgz
        profileName: cert-manager-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "prometheus.enabled": "false"
          "installCRDs": "true"
        cluster:
          - provider: edgeProvider
            label: certLabel
  - namespace: ${slice_ns}
    compAppName: ${compAppName}-common
    compAppVer: v1
    compProfileName: ${compProfName}-common 
    depIntGrpName: ${depIntGroup}-common
    lCloud: ${slice_ns}-common
    ovnIntent: true
    gacIntent: true
    dependency:
      - app: f5gc-nrf
        depApps:
          - app: f5gc-mongodb
            op: Ready
            wait: 2
      - app: f5gc-nssf
        depApps:
          - app: f5gc-nrf
            op: Ready
            wait: 2
      - app: f5gc-amf
        depApps:
          - app: f5gc-nssf
            op: Ready
            wait: 5
      - app: f5gc-webui
        depApps:
          - app: f5gc-nrf
            op: Ready
            wait: 2
    ovnNetworks:
      - app: f5gc-amf
        appType: Deployment
        ifName: net2
        nwName: sctpnetwork
        defaultGateway: false
        ipAddress: 172.16.24.3
    Apps:
      - name: f5gc-amf
        helmApp: f5gc-amf.tgz
        profileName: amf-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "service.type": ${serviceType}
          "configuration.sbi.registerIPv4": ${slice0_amf}
          "configuration.nrfUri": http://f5gc-nrf.${slice_ns}.${Domain}:${commonNRF}
          "mongodb.url": http://${mongo_url}:${mongo_port}
          "image.repository": "${containerRegistry}free5gc-amf"
          "image.tag": ${f5gcTag}
          "helmInstallOvn": "true"
        cluster:
          - provider: edgeProvider
            label: sliceCLabelA
        gac:
          - new: "false"
            resource:
              api: v1
              kind: Service
              name: f5gc-amf
            clusterSpecific: "false"
            type: json
            patch: |-
              [
                {
                  "op": "add",
                  "path": "/metadata/annotations",
                  "value": {
                    "external-dns.alpha.kubernetes.io/hostname": "f5gc-amf.${slice_ns}.${Domain}"
                  }
                }
              ]
      - name: f5gc-mongodb
        helmApp: f5gc-mongodb.tgz
        profileName: mongo-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "service.type": ${serviceType}
          "service.nodePort": "32017"
        cluster:
          - provider: edgeProvider
            label: sliceCLabelB
        gac:
          - new: "false"
            resource:
              api: v1
              kind: Service
              name: f5gc-mongodb
            clusterSpecific: "false"
            type: json
            patch: |-
              [
                {
                  "op": "add",
                  "path": "/metadata/annotations",
                  "value": {
                    "external-dns.alpha.kubernetes.io/hostname": "f5gc-mongodb.${slice_ns}.${Domain}"
                  }
                }
              ]
      - name: f5gc-nrf
        helmApp: f5gc-nrf.tgz
        profileName: nrf-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "service.type": ${serviceType}
          "service.port": "${commonNRF}"
          "service.nodePort": "${commonNRF}"
          "configuration.sbi.registerIPv4": f5gc-nrf.${slice_ns}.${Domain}
          "configuration.MongoDBUrl": "mongodb://${mongo_url}:${mongo_port}"
          "image.repository": "${containerRegistry}free5gc-nrf"
          "image.tag": ${f5gcTag}
        cluster:
          - provider: edgeProvider
            label: sliceCLabelB
        gac:
          - new: "false"
            resource:
              api: v1
              kind: Service
              name: f5gc-nrf
            clusterSpecific: "false"
            type: json
            patch: |-
              [
                {
                  "op": "add",
                  "path": "/metadata/annotations",
                  "value": {
                    "external-dns.alpha.kubernetes.io/hostname": "f5gc-nrf.${slice_ns}.${Domain}"
                  }
                }
              ]
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
          "configuration.nrfUri": http://f5gc-nrf.${slice_ns}.${Domain}:${commonNRF}
          "mongodb.url": "mongodb://${mongo_url}:${mongo_port}"
          "image.repository": "${containerRegistry}free5gc-nssf"
          "image.tag": ${f5gcTag}
        cluster:
          - provider: edgeProvider
            label: sliceCLabelB
        gac:
          - new: "false"
            resource:
              api: v1
              kind: Service
              name: f5gc-nssf
            clusterSpecific: "false"
            type: json
            patch: |-
              [
                {
                  "op": "add",
                  "path": "/metadata/annotations",
                  "value": {
                    "external-dns.alpha.kubernetes.io/hostname": "f5gc-nssf.${slice_ns}.${Domain}"
                  }
                }
              ]

      - name: f5gc-webui
        helmApp: f5gc-webui.tgz
        profileName: webui-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "service.type": ${serviceType}
          "mongodb.url": mongodb://${mongo_url}:${mongo_port}
          "image.repository": "${containerRegistry}free5gc-webui"
          "image.tag": ${f5gcTag}
        cluster:
          - provider: edgeProvider
            label: sliceCLabelB
        gac:
          - new: "false"
            resource:
              api: v1
              kind: Service
              name: f5gc-webui
            clusterSpecific: "false"
            type: json
            patch: |-
              [
                {
                  "op": "add",
                  "path": "/metadata/annotations",
                  "value": {
                    "external-dns.alpha.kubernetes.io/hostname": "f5gc-webui.${slice_ns}.${Domain}"
                  }
                }
              ]
  - namespace: sdewan-system
    compAppName: ${compAppName}-sdewan-crd
    compAppVer: v1
    compProfileName: ${compProfName}-sdewan-crd
    depIntGrpName: ${depIntGroup}-sdewan-crd
    lCloud: sdewan-manager
    Apps:
      - name: sdewan_controllers
        helmApp: sdewan_controllers.tgz
        profileName: sdewan-manager-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "namespace": sdewan-system
          "spec.sdewan.image": integratedcloudnative/sdewan-controller:0.4.1
        cluster:
          - provider: edgeProvider
            label: sdewanLabelA
  - namespace: httpcrd-system
    compAppName: ${compAppName}-f5gc-sub
    compAppVer: v1
    compProfileName: ${compProfName}-f5gc-sub
    depIntGrpName: ${depIntGroup}-f5gc-sub
    lCloud: httpcrd
    gacIntent: true
    dependency:
      - app: f5gc-subscriber
        depApps:
          - app: http-crd-controller
            op: Ready
            wait: 15
    Apps:
      - name: http-crd-controller
        helmApp: http-crd-controller.tgz
        profileName: httpcrd-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "image.repository": ${containerRegistry}httpcrdcontroller
          "image.tag": latest 
        cluster:
          - provider: edgeProvider
            label: httpLabelB
      - name: f5gc-subscriber
        helmApp: f5gc-subscriber.tgz
        profileName: f5gc-subscriber-profile
        profileFw: f5gc-default-pr.tgz
        values:
          "url": "http://f5gc-webui.${slice_ns}.${Domain}:5000"
          "plmnid": "20893"
          "imsiStart": "208930000000003"
          "numUsers": "1"
        cluster:
          - provider: edgeProvider
            label: httpLabelB
        gac:
          - new: "true"
            resource:
              api: v1
              kind: Service
              name: cdn-external-service
            resFile: externalDNSentry.yaml
            clusterSpecific: "true"
            cluster:
              scope: Label
              provider: edgeProvider
              name: dummy
              label: httpLabelB

NET
}

deploy_slice_common_apps () {
	echo "Deploying the slice common Apps using EMCO..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/slice_common_prerequisites.yaml -v ${valuesFile} -w 2 &>> ${logFile}
	echo "Creating Logical Clouds ..."
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/logical_cloud.yaml -v ${valuesFile} -w 2 &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/logical-clouds/sdewan-manager/status?type=cluster" "Logical Cloud: sdewan-manager" 20
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/logical-clouds/${slice_ns}-common/status?type=cluster" "Logical Cloud: ${slice_ns}-common" 20
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/logical-clouds/cert-manager/status?type=cluster" "Logical Cloud: cert-manager" 20
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/logical-clouds/httpcrd/status?type=cluster" "Logical Cloud: httpcrd" 20
	echo "-----------------------------------------------------------------------"
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/ovn-network.yaml -v ${valuesFile} -w 5 &>> ${logFile}
	${EMCOCTL} --config ${emcoCFGFile} apply -f ${emcodir}/provider/common_sliceapps_deploy.yaml -v ${valuesFile} -w 15 &>> ${logFile}
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-cert/v1/deployment-intent-groups/${depIntGroup}-cert/status?type=cluster" "App: certificate-manager" 120
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-common/v1/deployment-intent-groups/${depIntGroup}-common/status?type=cluster" "App: free5gc  common" 120
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-sdewan-crd/v1/deployment-intent-groups/${depIntGroup}-sdewan-crd/status?type=cluster" "App: sdewan-crd-controller" 120
	check_status ${emcoCFGFile} ${logFile} "projects/${projName}/composite-apps/${compAppName}-f5gc-sub/v1/deployment-intent-groups/${depIntGroup}-f5gc-sub/status?type=cluster" "App: f5gc-subscriber-controller" 120
	echo "-----------------------------------------------------------------------"
}

uninstall_slice_common_apps () {
	echo "Uninstalling the Free5gc using EMCO..."
	providerDir=${emcodir}/provider

	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/common_sliceapps_deploy.yaml -v ${valuesFile} -w 15
	sleep 15
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/common_sliceapps_deploy.yaml -v ${valuesFile} -w $WAIT
	sleep 5

	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/ovn-network.yaml -v ${valuesFile} -w 5
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/ovn-network.yaml -v ${valuesFile} -w 5
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/logical_cloud.yaml -v ${valuesFile} -w 10
	sleep 5
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/logical_cloud.yaml -v ${valuesFile} -w $WAIT
	sleep 10
	${EMCOCTL} --config ${emcoCFGFile} delete -f ${providerDir}/slice_common_prerequisites.yaml -v ${valuesFile} -w $WAIT

}
if [ $action == "install" ]; then
	tar_charts ${emcodir}/../Charts
	create_slice_common_values
	deploy_slice_common_apps
elif [ $action == "uninstall" ]; then
	uninstall_slice_common_apps
else
	echo "unknown action. Allowed: install / uninstall"
fi

