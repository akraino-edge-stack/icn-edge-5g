***Helm Charts***

The Helm Charts for different Free5GC NFs and other components that are used for creating slices by the EMCO orchestration.

The emco scripts in the emco folder use these charts during the deployment of the Network functions for the slices.

```
cert-manager        -   Certificate Manager required for the sdewan CRD and other custom controllers.
demo-nginx-rtmp     -   A demo nginx rtmp streaming server, used as a MEC application and to demonstrate traffic steering.
external-dns        -   Chart for the external-dns project from kubernetes-sigs. Used for creating DNS entries in the external power DNS server.
sdewan-controller   -   Chart for the SDEWAN CRD controller from icn-sdewan akraino project.
http-crd-controller -   A sample controller that exposes Restful APIs to create free5gc subscribers. Plan is to replace this later with KNRC.

Free5GC NFs: 

```
**Links:**

- [Free5Gc](https://www.free5gc.org/)
- [external-dns](https://github.com/kubernetes-sigs/external-dns)
- [icn-sdewan](https://github.com/akraino-edge-stack/icn-sdwan)
- [cert-manager](https://github.com/jetstack/cert-manager)



