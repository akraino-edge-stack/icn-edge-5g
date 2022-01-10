**EMCO Deployment Scripts**
- EMCO scripts used to deploy the slices.
- emcoctl is used to apply the scripts.


***Slice Deployment***
- This folder contains the artifacts and scripts to deploy the slices.
- The sequence of steps that are involved in the deploying of slices are as below,
    * Initialize the EMCO (controllers and target cluster).
    * Deploy emco-monitor.
    * external-dns and metallb load-balancer.
    * Creation of logical clouds: different namespaces.
    * Deploy the applications common to all slices.
	- cert-manager
	- Free5g NFs: AMF, NSSF, mongodb, webui
	- sdewan-crd controller
	- f5gc subscriber controller.
    * Deploy the first slice components.
    * Deploy the second slice components.
    * Deploy the demo nginx (MEC) application.

***Folder Structure***
- emco-init    : Files and artifacts needed for emco (controller) initalization.
- provider     : Artifacts needed for deploying the applications that are common to all the slices.
	         This also includes the emco-monitor, external-dns, metallb deployment artifacts.
- slice-utils  : Scripts to deploy the applications, slice NFs, demo MEC application etc.,
- slice-a      : Artifacts for the first slice (on slice-a namespace)
- slice-b      : Artifacts for the first slice (on slice-b namespace)
- demo-mec-app : Demo MEC Application artifacts.
- monitor      : Charts and files for deploying the emco-monitor.


***Documentation:***
- Refer to the docs folder in the repo for test setup and installation / deployment instructions.
