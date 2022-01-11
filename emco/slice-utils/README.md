**Slice Deployment Scritps**

This folder contains the scripts required to deploy the
```
	- provider : emco-monitor, external-dns, metallb 
	- common slice apps : cert-manager, f5gc-mongodb, f5gc-amf, f5gc-nssf, f5gc-webui, sdewan-crd, f5gc-subscriber controller
	- slice deploument: Deploys the slcie NFs.
	- mec Application: Deploys the MEC application.
	- common-helper: Contains variables and functions that are common to all the scripts. Sourced in all other scritps. 

```

***Folder Contents***

The files and their purposes are as below,
```
common_helpers.sh		- Functions and variables that are common for all the scripts. Sourced in all the scripts.
deploy_provider.sh		- Script to deploy the emco-monitor, external-dns and metallb.
deploy_common_sliceapps.sh	- Script to deply apps common to all the slices: cert-manager, amf, nrf, nssf, webui etc.,
deploy_slice.sh			- Used to deploy the slices. It takes the configfile as parameter.
					The config files for each slice are available in the respective folders: slice-a, slice-b
deploy_mecapp.sh		- Used to deploy the demo MEC application. Takes the slice namespace as argument.

```

Refer to the docs folder for deployment instructions.

