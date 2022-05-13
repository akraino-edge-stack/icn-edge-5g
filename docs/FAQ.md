# Frequently Asked Questions

# Table of Contents:
<!--- TOC BEGIN -->
* [Basics](#basics)
  * [What is icn edge 5g repo about?](#what-is-icn-edge-5g-repo-about)
  * [What are the software components and version used?](#what-are-the-software-components-and-versions-used)
  
* [Troubleshooting](#troubleshooting)
  * [The provider application pods fail to start or exit with an error. Why?](#The-provider-application-pods-fail-to-start-or-exit-with-an-error.-Why?)
  * [The CNF or application containers failed to start. Why?](#The-CNF-or-application-containers-failed-to-start.-Why?)
  * [How do I check the DNS entries for the CNF services in the external powerDNS server?](#How-do-I-check-the-DNS-entries-for-the-CNF-services-in-the-external-powerDNS-server?)
 <!--- TOC END -->
 
 # Basics

### What is icn edge 5g repo about?

The icn-edge-5g repo provides the necessary scripts and config files required for automated deployment and configuration of 5G network slices. The slices can be spread across multiple clusters. EMCO is used as the multi-cluster orchestrator. Presently Free5gc is used as the 5G core. But the scripts and config can be easily extended to support any other 5G core.

### What are the software components and version used?

Multiple open-source software components are used:

Cluster Orchestrator - Kubernetes Version 1.23.0

CNI: [NODUS](https://github.com/akraino-edge-stack/icn-nodus)

EMCO - [Edge Multi Cluster Orchestrator V22.03](https://gitlab.com/project-emco/core/emco-base/-/tree/v22.03)

5G core: [Free5GC v3.0.6](https://github.com/free5gc/free5gc/tree/v3.0.6)

ue ran simulator : [UERANSIM v3.1.0](https://github.com/aligungr/UERANSIM/tree/v3.1.0)

external DNS Provider: PowerDNS
 
Synchronize the service FQDN with external DNS Provider: [external-dns](https://github.com/kubernetes-sigs/external-dns)

loadbalancer services: [metallb](https://metallb.universe.tf/)

SDEWAN cnf and crd controller: [SDEWAN](https://github.com/akraino-edge-stack/icn-sdwan)



# Troubleshooting:

### The provider application pods fail to start or exit with an error. Why?

Check the proxy settings and the proxy configuration for the docker and kubernetes. 

The proxy configuration file for docker is at "/etc/systemd/system/docker.service.d/http-proxy.conf". 

The proxy configuration file for kubelet is here : "/usr/lib/systemd/system/kubelet.service.d/http-proxy.conf".

If adding proxy server for external communication, ensure that the no_proxy is properly set. Do not forget to include the following subnets

".svc", ".svc.cluster.local", ".cluster.local", service-ip-range, loadbalancer-ip-range, host-subnet, pod-subnet etc., to the no_proxy configuration.

Also, check if the firewall is disabled (This is required until we add / test the proper fw rules).


### The CNF or application containers failed to start. Why?

Check the docker registry is properly configured and accessible from all the clusters. Set the DOCKER_REPO variable to point to the docker registry (with a / in front).

### How do I check the DNS entries for the CNF services in the external powerDNS server?

Use the pdnsutil command to check the DNS entries in the powerDNS server
```
sudo pdnsutil list-zone <domain-name>
sudo pdnsutil list-zone f5gnetslice.com
```



