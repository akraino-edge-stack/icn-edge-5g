#! /bin/bash

cd ../Charts
#for i in mongodb nrf udr udm ausf nssf amf pcf brupf upfa upfb
for i in mongodb nrf udr udm ausf nssf amf pcf upf smf
do
	cd f5gc-$i && helm install free5g-$i ./
	if [ $? -ne 0 ]; then
		echo "failed to install $i"
	       	exit 2
	fi
	cd ..
	sleep 8
	kubectl get pods -o wide | grep $i
done

kubectl get pods -o wide

