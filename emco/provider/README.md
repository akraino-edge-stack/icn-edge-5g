**PROVIDER**

This folder containts artifacts that are required for deploying basic and common slice applications:
```
	- emco-monitor
	- external-DNS
	- metallb
	- creation of logical clouds (namespaces)
	- certificate manager
	- Free5gc Apps:	
		* mongodb
		* amf
		* nrf
		* nssf
		* webui
	- sdewan crd controller
	- freegc subscriber controller.
```

***Folder Contents***

The files and their purposes are as below,
```
prerequisites.yaml		- Artifacts for creating EMCO project and cluster references, labels etc.,
monitor.yaml		- EMCO artifacts for deploying the emco-monitor
deploy_edns_metallb.yaml	- emcoctl script to deploy external-DNS and metallb.
logical_cloud.yaml		- Artifacts for creating logical clouds.
ovn-network.yaml		- EMCO emcoctl script with ovnaction controller intents.
common_sliceapps_deploy.yaml	- Artifacts to deploy the slice common applications (cert-manager, amf, nssf etc.,)
```

Refer to the docs folder for test setup and steps to deploy the slices.
