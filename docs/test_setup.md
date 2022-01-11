**Test Setup for Network Slicing Demo**

***1. Test Setup***

<img src=slice_test_setup.png >

- In the setup above:
    * Cluster-A : used for EMCO, is a single node cluster.
    * CLuster-B : Target cluster with one minion node, used for deploying AMF, SMF, UPF, SDEWAN CRD controller.
    * Cluster-C : Target cluster, single node cluster, used for NRF, UDR, UDM, NSSF, f5gc subscriber controller etc.,
    * VM-Router : Linux VM configured to work as a router. It also has power-DNS server installed.
    * UE-RAN Sim: Linux VM where we will run the UE-RAN simulator to connect to the Free5GC core NFs.
- All the VMs are installed with operating system : Ubuntu 20.04.2 LTS

***2. Software Components***

****2.1 Kubernetes:****
- Ensure that the kubernetes is installed on clusters A, B and C.
- [Kubernetes](https://github.com/kubernetes/kubernetes)

****2.2 Nodus CNI:****
- Install NODUS (ovn4nfv) in Cluster-B and Cluster-C as primary CNI.
- Please refer to this [link](https://github.com/akraino-edge-stack/icn-nodus) for details.

****2.3 DNS Server****
- we have used power-DNS as the DNS server running in the VM-Router Virtual Machine.
- Refer: [PowerDNS](https://www.powerdns.com/)
Note: Any other DNS server supported by external-DNS can be used.
- Steps used to install the powerDNS server:
```
    sudo apt install pdns-server
    sudo apt-get install pdns-backend-sqlite3
```
- Configuration file:
```
    api=yes
    api-key=<api_key: NETSLICING>
    log-dns-queries=yes
    loglevel=9
    webserver-address=0.0.0.0
    webserver-allow-from=<ip_subnet>
    launch=gsqlite3
    gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
```
- Setup the sqlite3 and restart the pdns service.
```
    sudo mkdir /var/lib/powerdns
    sudo apt-get install sqlite3
    sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
    sudo systemctl restart pdns
    systemctl status pdns.service
```
- Create the DNS zone
```
    sudo pdnsutil create-zone f5gnetslice.com
```

****2.4 External-DNS:****
- ExternalDNS synchronizes exposed Kubernetes Services and Ingresses with DNS providers.
- Deployed on Target clusters (Cluster-B and Cluster-C in the setup above).
- Used to create DNS entries for services running in cluster-B, Cluster-C in the power-DNS server running in the VM-Router VM.
- DNS entries for external services can also be added to the server.
- Refer: [external-dns](https://github.com/kubernetes-sigs/external-dns)
Note: The helm chart for the external-dns is also available in the Charts folder of this repo.
- The external-dns is now deployed automatically from EMCO cluster using the deploy_provider.sh.
- Manual Installation steps when using power-DNS server is as below,
```
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm pull bitnami/external-dns
    cd external-dns
    helm install --set provider=pdns --set pdns.apiUrl=http://<ip_address_of_vm_router> --set pdns.apiKey=<api_key: NETSLICING> --set txtOwnerId=<owner_id> --set logLevel=debug --set interval=30s --set policy=sync external-dns ./
```
Note: The above manual steps are not required when using the deploy_provider.sh script.

****2.5 Metallb (LoadBalancer):****
- load-balancer implementation for bare metal Kubernetes clusters.
- Deployed on Target clusters (Cluster-B and Cluster-C in the setup above).
- Refer: [Metallb](https://github.com/metallb/metallb)
-  The metallb is now deployed automatically from EMCO cluster using the deploy_provider.sh. 
- This script also has the proper GAC intents to create / modify the configuration.

Metallb Deployment Values file (metallb_values.yaml) used for manual helm deployment:
```
configInline:
  address-pools:
   - name: default
     protocol: layer2
     addresses:
     - < IP address range to be used for loadbalancer services >
```
To deploy:
```
    helm repo add metallb https://metallb.github.io/metallb
    helm pull metallb/metallb
    tar xvfz metallb-0.11.0.tgz
    cd metallb/
    helm install metallb ./ -f ../<path_to_values_file metallb_values.yaml>
```
Note: The above manual steps are not required while using the deploy_provider.sh script during deployment.

****2.6 set CoreDNS to also use the powerDNS server for DNS resolution****
- Modify the coredns configmap to also use the powerDNS to resolve the FQDNs.
- This is needed on target clusters B and C.
```
> kubectl edit -n kube-system cm coredns   # Add the following lines to the configmap

    f5gnetslice.com:53 {
        errors
        cache 30
        forward . <ip_address_of_PDNS_Server>
    }
```

****2.7 Free5GC gtp kernel Module:****
- Ensure the gtp5g.ko module is properly loaded in the minion node of cluster B. 
- This is required for free5gc UPF.
  	Refer to: [https://github.com/free5gc/free5gc/wiki/Installation]

****2.8 UERAN Simulator****
- Install UERAN Simulator.
- This is required only on the UE-RAN simulator VM and compile the UE-RAN simulator.
- For details refer: [link](https://github.com/aligungr/UERANSIM)

****2.9 Route Entries****
- setup the route entries on all the VMs and the VM-Router VM, so that each VM can access the other VMs.

****2.10 EMCO****
- Install the EMCO on the Cluster-A.
- Refer to the [link](https://gitlab.com/project-emco/core/emco-base) for details regarding EMCO and installation instructions.
- Copy the kubeconfig files from the target clusters B and C to the Cluster-A for emco to use them.
