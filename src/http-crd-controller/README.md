***HTTP CRD Controller***
- Exposes RESTful APIs to interact with the free5gc webui.
- k8s native approach to create Free5GC subscribers.
**NOTE** 
This k8s controller is specific for the Free5Gc, used to interact with the free5gc-webui to add subscribers to the DB.
This will be replaced by the KNRC (K8s Native Restful Controller): A generic RESTful API controller for the k8s.

***Build Instructions***
1. export the DOCKER_REPO variable with the proper docker registry to which the generated image will be pushed.
**NOTE:** Add a forward slash (/) at the end
```
export DOCKER_REPO=<Docker Registry>/

```

2. Install gcc (Needed for cgo)
```
sudo apt-get install gcc
```

3. Download the free5gc webui apis
```
go get -t slice.free5gc.io/webui/api/v1alpha1
```

4. Build the image
```
make docker-build
```

5. push the image to the docker registry.
```
make docker-push
```

