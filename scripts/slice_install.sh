#! /bin/bash


NS=(default prioslice)

cpdp=${1:-"cplane"}

if [ $cpdp == "cplane" ]; then
	if [ $# -gt 1 ]; then
		echo "Illegal parameters for cplane"
		echo "$0 cplane"
		exit 2
	fi
	NF_0=(mongodb nrf udr udm ausf nssf pcf)
	NF_1=(nrf udr udm ausf pcf)
	cPlaneIP=$(hostname -I | cut -f 1 -d " ")
elif [ $cpdp == "dplane" ]; then
	if [ $# -ne 2 ]; then
		echo "Illegal parameters for dplane"
		echo "$0 dplane <cplane_node_IP>"
		exit 2
	fi
	NF_0=(amf upf smf)
	NF_1=(upf smf)
	dPlaneIP=$(hostname -I | cut -f 1 -d " ")
	cPlaneIP=$2
	kubectl apply -f yaml-files/ovn4nfv_f5gc_pn.yaml
else
	echo "Unknown Option $cpdp"
	echo "Allowed options are: cplane dplane"
	exit 2
fi

function check_status_exit {
	if [ $? -ne 0 ]; then
		echo "failed to install $2 in $1 namespace"
		exit 2
	fi
	titr=60
	for i in $(seq 1 $titr); do
		sleep 1
		kubectl get pods -n $1 | grep $2 | grep unning
		if [ $? -eq 0 ]; then
			echo "$2 running in $1 namespace"
			return 0
		fi
 		if [ $i -eq $titr ]; then
			echo "$2 NF failed to run in the $1 namespace"
			exit 2
		fi
	done		
}
cd ../Charts/
for f5gnf in ${NF_0[@]}; do
	case "${f5gnf}" in
		mongodb) echo "Installing mongodb"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set service.nodePort=32023 free5g-mongodb-${NS[0]} ./f5gc-mongodb/
			check_status_exit ${NS[0]} mongodb
			;;
		nrf) echo "Installing nrf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set image.repository=registry.fi.intel.com/palaniap/free5gc-nrf --set image.tag=3.0.5 free5g-nrf-${NS[0]} f5gc-nrf/
			check_status_exit ${NS[0]} nrf
			;;
		udr) echo "Installing udr in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set image.repository=registry.fi.intel.com/palaniap/free5gc-udr --set image.tag=3.0.5 free5g-udr-${NS[0]} f5gc-udr/
			check_status_exit ${NS[0]} udr
			;;
		udm) echo "Installing udm in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set image.repository=registry.fi.intel.com/palaniap/free5gc-udm --set image.tag=3.0.5 free5g-udm-${NS[0]} f5gc-udm/
			check_status_exit ${NS[0]} udm
			;;
		ausf) echo "Installing ausf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set image.repository=registry.fi.intel.com/palaniap/free5gc-ausf --set image.tag=3.0.5 free5g-ausf-${NS[0]} f5gc-ausf/
			check_status_exit ${NS[0]} ausf
			;;
		nssf) echo "Installing nssf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set nssaiNrfUri1=http://${cPlaneIP}:32510 --set nssaiNrfUri2=http://${cPlaneIP}:32510 --set nssaiNrfUri3=http://${cPlaneIP}:32510 --set nssaiNrfUri4=http://${cPlaneIP}:32510 --set nssaiNrfUri5=http://${cPlaneIP}:32511 --set nssaiNrfUri6=http://${cPlaneIP}:32511 --set nssaiNrfUri7=http://${cPlaneIP}:32510 --set nssaiNrfUri8=http://${cPlaneIP}:32510 --set image.repository=registry.fi.intel.com/palaniap/free5gc-nssf --set image.tag=3.0.5 free5g-nssf-${NS[0]} f5gc-nssf/
			check_status_exit ${NS[0]} nssf
			;;
		pcf) echo "Installing pcf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${cPlaneIP} --set image.repository=registry.fi.intel.com/palaniap/free5gc-pcf --set image.tag=3.0.5 free5g-pcf-${NS[0]} f5gc-pcf/
			check_status_exit ${NS[0]} pcf
			;;
		amf) echo "Installing amf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${dPlaneIP}  --set configuration.nrfUri=http://${cPlaneIP}:32510 --set configuration.mongodb.url=http://${cPlaneIP}:32017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-amf --set image.tag=3.0.5 free5g-amf-${NS[0]}  ./f5gc-amf/
			check_status_exit ${NS[0]} amf
			;;
		upf) echo "Installing upf in ${NS[0]} namespace"
			kubectl  create ns cert-manager
		        helm install --namespace cert-manager --set prometheus.enabled=false --set installCRDs=true cert-manager ../../Charts/cert-manager/
			sleep 10
			helm install --namespace ${NS[0]} --set image.repository=registry.fi.intel.com/palaniap/free5gc-upf --set image.tag=3.0.5 free5g-upf-${NS[0]} ./f5gc-upf/
			check_status_exit ${NS[0]} upf
			kubectl create ns sdewan-system
			helm install --set namespace=sdewan-system --set spec.sdewan.image=sdewan-controller:dev sdewan-ctrlr ../../Charts/sdewan_controllers/
			;;
		smf) echo "Installing smf in ${NS[0]} namespace"
			helm install --namespace ${NS[0]} --set service.type=NodePort --set configuration.sbi.registerIPv4=${dPlaneIP}  --set configuration.nrfUri=http://${cPlaneIP}:32510 --set configuration.mongodb.url=http://${cPlaneIP}:32017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-smf --set image.tag=3.0.5 free5g-smf-${NS[0]} f5gc-smf/
			check_status_exit ${NS[0]} smf
			;;
	esac
done

# prioslice namespace *******************
kubectl create ns ${NS[1]}

for f5gnf in ${NF_1[@]}; do
	case "${f5gnf}" in
		nrf) echo "Installing nrf in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} --set service.type=NodePort --set service.port=32511 --set service.nodePort=32511 --set configuration.sbi.registerIPv4=${cPlaneIP} --set configuration.MongoDBUrl=mongodb://f5gc-mongodb.default:27017  --set image.repository=registry.fi.intel.com/palaniap/free5gc-nrf --set image.tag=3.0.5 free5g-nrf-${NS[1]} f5gc-nrf/
			check_status_exit ${NS[1]} nrf
			;;
		udr) echo "Installing udr in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} --set service.type=NodePort --set service.port=32505 --set service.nodePort=32505 --set configuration.sbi.registerIPv4=${cPlaneIP} --set configuration.nrfUri=http://f5gc-nrf:32511 --set configuration.mongodb.url=mongodb://f5gc-mongodb.default:27017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-udr --set image.tag=3.0.5 free5g-udr-${NS[1]} f5gc-udr/
			check_status_exit ${NS[1]} udr
			;;
		udm) echo "Installing udm in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} --set service.type=NodePort --set service.port=32502 --set service.nodePort=32502 --set configuration.sbi.registerIPv4=${cPlaneIP} --set configuration.nrfUri=http://f5gc-nrf:32511 --set configuration.mongodb.url=mongodb://f5gc-mongodb.default:27017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-udm --set image.tag=3.0.5 free5g-udm-${NS[1]} f5gc-udm/
			check_status_exit ${NS[1]} udm
			;;
		ausf) echo "Installing ausf in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} --set service.type=NodePort --set service.port=32508 --set service.nodePort=32508 --set configuration.sbi.registerIPv4=${cPlaneIP} --set configuration.nrfUri=http://f5gc-nrf:32511 --set configuration.mongodb.url=mongodb://f5gc-mongodb.default:27017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-ausf --set image.tag=3.0.5 free5g-ausf-${NS[1]} f5gc-ausf/
			check_status_exit ${NS[1]} ausf
			;;
		pcf) echo "Installing pcf in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} --set service.type=NodePort --set service.port=32590 --set service.nodePort=32590 --set configuration.sbi.registerIPv4=${cPlaneIP} --set configuration.nrfUri=http://f5gc-nrf:32511 --set configuration.mongodb.url=mongodb://f5gc-mongodb.default:27017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-pcf --set image.tag=3.0.5 free5g-pcf-${NS[1]} f5gc-pcf/
			check_status_exit ${NS[1]} pcf
			;;
		upf) echo "Installing upf in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} -f f5gc-upf/values-prio.yaml --set image.repository=registry.fi.intel.com/palaniap/free5gc-upf --set image.tag=3.0.5 free5g-upf-${NS[1]} ./f5gc-upf/
			check_status_exit ${NS[1]} upf
			sleep 10
			;;
		smf) echo "Installing smf in ${NS[1]} namespace"
			helm install --namespace ${NS[1]} -f f5gc-smf/values-prio.yaml --set service.type=NodePort --set service.port=32505 --set service.nodePort=32505 --set configuration.sbi.registerIPv4=${dPlaneIP}  --set configuration.nrfUri=http://${cPlaneIP}:32511 --set configuration.mongodb.url=http://${cPlaneIP}:32017 --set image.repository=registry.fi.intel.com/palaniap/free5gc-smf --set image.tag=3.0.5 free5g-smf-${NS[1]} f5gc-smf/
			check_status_exit ${NS[1]} smf
			;;
	esac
done

kubectl get pods -o wide -n ${NS[0]}

kubectl get pods -o wide -n ${NS[1]}

