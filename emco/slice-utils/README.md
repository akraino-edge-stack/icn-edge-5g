**Slice Deployment Scritps**
This folder contains the scripts required to deploy the
	- provider : emco-monitor, external-dns, metallb  (deploy_provider.sh)
	- common slice apps : cert-manager, f5gc-mongodb, f5gc-amf, f5gc-nssf, f5gc-webui, sdewan-crd, f5gc-subscriber controller (deploy_common_sliceapps.sh)
	- slice deploument: Deploys the slcie NFs. Takes namespace as argument. (deploy_slice.sh)
	- mec Application: Deploys the MEC application. Takes namespace as argument. (deploy_mecapp.sh)
	- common-helper: Contains variables and functions that are common to all the scripts. Sourced in all other scritps. (common_helper.sh)

Refer to the docs folder for deployment instructions.

