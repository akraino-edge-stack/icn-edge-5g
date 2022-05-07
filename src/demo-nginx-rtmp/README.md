***Demo MEC Application Image***
- Dockerfile to create a sample demo MEC application.
- This uses the nginx-rtmp image to stream video.
- Copy a sample video file into this folder as "video.mp4".

***Build Instructions***
1. export the DOCKER_REPO variable with the proper docker registry to which the generated image will be pushed.
**NOTE:** Add a forward slash (/) at the end
```
export DOCKER_REPO=<Docker Registry>/

```
2. Copy a video file to this folder as "video.mp4" as it will be bundled with the image.
```
cp <video mp4 file> video.mp4
```

3. Run Make to build the image and push to the docker registry.
```
make all

```
The image demo-nginx-rtmp:latest will be created and pushed to the DOCKER_REPO.
**NOTE** An example helm chart to deploy this image with nginx config is available in the charts folder: Charts/demo-nginx-rtmp/
**NOTE** The config file required for the nginx is provided by this chart using the configmap resource.

