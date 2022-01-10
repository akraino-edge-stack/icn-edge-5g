**Demo MEC Application**

* A nginx based rtmp streaming application to demonstrate:
	- deployment of demo MEC applications in the edge.
	- The demo MEC application can be deployed to each slice namespace.
	- Traffic steering using SDEWAN-CRD to the demo MEC application.


* nginx with rtmp streaming is used to stream a sample video.
* Files and instructions required to create the demo MEC application container is available in the src folder.

***Traffic Redirection***
- The SDEWAN CRD "CNFLocalService" resource is used to redirect the traffic to the MEC application.
- This resource creates the required IPTable rules in the UPF pod to re-direct the traffic to the MEC application.
- The SDEWAN cnf which is part of the UPF pod is responsible for creating the IPTable Rules.

```
apiVersion: batch.sdewan.akraino.org/v1alpha1
kind: CNFLocalService
metadata:
  name: nat-steer-${slice_ns}
  namespace: ${slice_ns}
  labels:
    sdewanPurpose: sdewan-safe-${slice_ns}

spec:
  localservice: demo-nginx-rtmp.${slice_ns}.${Domain}
  remoteservice: www.cdn.${Domain}
```
