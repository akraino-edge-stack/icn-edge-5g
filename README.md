**5G Network Slicing**

- Deployment of 5G Network Slicing using EMCO.
- Free5GC NFs are used for creating the slices.

***Repository***
- This repository contains the helm charts and EMCO scripts required to deploy the 5G Network slices.

****Contents:****
* Charts  - Helm Charts for the Free5G core NFs and other components.
* docs    - Documents for test setup, prerequisites, slice deployment etc.,
* emco    - EMCO scripts that are used to setup the required software and deploy the slices.
* scripts - kubectl scripts for slice deployment (used for testing only).
* src     - Sources for the Free5gc subscriber controller etc.,

***Developer Guide***
-
- Refer to the docs folder for test setup and installation steps. 
- Here are the links,
    * [prerequisites and test setup](docs/test_setup.md)
    * [Steps to Build free5gc docker images](docs/free5g.md)
    * [Steps to deploy network slices](docs/README.md)
    * [free5gc subscriber controller](src/http-crd-controller/README.md)
    * [demo nginx application](src/demo-nginx-rtmp/README.md)


