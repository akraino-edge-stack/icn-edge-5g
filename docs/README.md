**5G Network Slicing Deployment**

***1.0 Prerequisites***

****1.1 Test Setup****
- Ensure the test setup is brought up and all the required components are installed.
- Please refer to the [test_setup.md](test_setup.md) for details.

****1.2 Free5GC Images****
- The network slicing has been tested using Free5GC NFs from version 3.0.5.
- To create the Free5gc V3.0.5 images refer to the [free5g.md](free5g.md) for details.

****1.3 Subscriber Controller and Demo App Images****
- A Free5gc subscriber controller and a demo MEC app (demo-nginx-rtmp) is added in the src folder.
- To create the images: cd to the respective folders and follow the Readme files.
    * free5gc subscriber controller : cd src/http-crd-controller and follow the [Readme.md](../src/http-crd-controller-README.md)
    * demp-nginx-rtmp: cd src/demo-nginx-rtmp and follow the [Readme.md](../src/demo-nginx-rtmp/README.md)

***2.0 Deployment of network slices using EMCO***
- The slices are deployed from the cluster-A which has the EMCO installed. The steps to deploy are as below,
Go to the slice-utils folder, as all the scripts are run from here.
```
cd emco/slice-utils
```

****2.1 Provider:****
- This steps deploys the emco-monitor, external-dns, metallb and configures them properly (using GAC intents).
- The script deploy_provider.sh is used to deploy as below,
```
./deploy_provider.sh install
```
The output of the above execution is as below,
```
EMCO initializing...
-----------------------------------------------------------------------
Instantiating App: emco-monitor ...Done, successful.
-----------------------------------------------------------------------
Deploying the Provider using EMCO...
Instantiating App: provider ...Done, successful.
-----------------------------------------------------------------------
```

****2.2 Deploy Slice common Apps:****
- Deploys the applications that are common / required for all the slices.
- The applications deployed include: cert-manager, amf, nrf, nssf, mongodb, webui, sdewan crd, f5gc subscriber controller.
- The script deploy_common_sliceapps.sh is used.
```
./deploy_common_sliceapps.sh install
```
The output is as below,
```
Deploying the slice common Apps using EMCO...
Creating Logical Clouds ...
Instantiating Logical Cloud: sdewan-manager ..Done, successful.
Instantiating Logical Cloud: slice-common ..Done, successful.
Instantiating Logical Cloud: cert-manager ..Done, successful.
Instantiating Logical Cloud: httpcrd ..Done, successful.
-----------------------------------------------------------------------
Instantiating App: certificate-manager ..Done, successful.
Instantiating App: free5gc  common ..Done, successful.
Instantiating App: sdewan-crd-controller ..Done, successful.
Instantiating App: f5gc-subscriber-controller ..Done, successful.
-----------------------------------------------------------------------
```

****2.3 Deploy Slices:****
- The slices are deployed in their own namespace.
- The folders "slice-a" and "slice-b" contain the configfiles required to config the slices.
- The scipt "deploy_slice is used. It takes the configfile as argument.
- The script is invoked multiple times with different config files to create more slices.
- To create the first slice (on slice-a namespace)
```
./deploy_slice.sh --configfile=../slice-a/slice-config install
```
The output for this command is as below,
```
namespace: slice-a
Deploying the Slice NFs using EMCO...
-----------------------------------------------------------------------
Creating Logical Cloud slice-a ...
Instantiating Logical Cloud: slice-a ..Done, successful.
-----------------------------------------------------------------------
Deploying a new slice on namespace slice-a...
Instantiating App: free5gc prio slice-a ...............Done, successful.
-----------------------------------------------------------------------
```

- To create the second slice (on slice-b namespace)
```
./deploy_slice.sh --configfile=../slice-b/slice-config install
```
The output for this command is as below,
```
namespace: slice-b
Deploying the Slice NFs using EMCO...
-----------------------------------------------------------------------
Creating Logical Cloud slice-b ...
Instantiating Logical Cloud: slice-b ..Done, successful.
-----------------------------------------------------------------------
Deploying a new slice on namespace slice-b...
Instantiating App: free5gc prio slice-b ......................Done, successful.
-----------------------------------------------------------------------
```

The slice deployment is depicted as below,
<img src=slice_NF_Deployment.png>

****2.4 Deploy Demo MEC Application:****
- The nginx-rtmp streaming is used as a demo MEC application. 
- The script "deploy_mecapps.sh" is used.
- It deploys the demo-nginx-rtmp and also installs the CRD for traffic redirection to the MEC application.
- It takes the slice namespace as the argument on which the app is deployed.
- To deploy the app on the slice-b namespace,
```
./deploy_mecapp.sh --namespace=slice-b install
```
and the output is as below,
```
namespace: slice-b
Deploying the MEC App using EMCO...
Deploying mecApp and Installing Traffic Steering Rules ...
Instantiating App: MEC App slice-b with Traffic steering Rules ..Done, successful.
-----------------------------------------------------------------------
```

***3.0 Establishing and Testing the PDU Sessions using UE-RAN Simulator***
- login to the UE-RAN Simulator VM
- Run the gnodeb simulator
```
./build/nr-gnb -c config/free5gc-gnb-prio.yaml
```

 example config for the gnb is as below (modify the IP addresses as required),
```
mcc: '208'          # Mobile Country Code value
mnc: '93'           # Mobile Network Code value (2 or 3 digits)

nci: '0x000000010'  # NR Cell Identity (36-bit)
idLength: 32        # NR gNB ID length in bits [22...32]
tac: 1              # Tracking Area Code

linkIp: 127.0.0.1   # gNB's local IP address for Radio Link Simulation (Usually same with local IP)
ngapIp: 172.16.24.2   # gNB's local IP address for N2 Interface (Usually same with local IP)
gtpIp: 172.16.34.2    # gNB's local IP address for N3 Interface (Usually same with local IP)

# List of AMF address information
amfConfigs:
  - address: 172.16.24.3
    port: 38412

# List of supported S-NSSAIs by this gNB
slices:
  - sst: 0x1
    sd: 0x010203
  - sst: 0x2
    sd: 0x010203


# Indicates whether or not SCTP stream number errors should be ignored.
ignoreStreamIds: true
```
- Run the UE simulator as below,
```
sudo ./build/nr-ue -c config/free5gc-ue-slice.yaml -n 1
```
and the example config file ia as below,
```
# IMEISV number of the device. It is used if no SUPI and IMEI is provided
imeiSv: '4370816125816151'

# List of gNB IP addresses for Radio Link Simulation
gnbSearchList:
  - 127.0.0.1

# Initial PDU sessions to be established
sessions:
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 0x01
      sd: 0x010203
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 0x02
      sd: 0x010203

# List of requested S-NSSAIs by this UE
slices:
  - sst: 0x01
    sd: 0x010203
  - sst: 0x02
    sd: 0x010203

# Supported encryption and integrity algorithms by this UE
integrity:
  IA1: true
  IA2: true
  IA3: true
ciphering:
  EA1: true
  EA2: true
  EA3: true
```
Note: Modify the slice configuration as required. It should match with the values used to create subscribers in the Free5gc database (in the deployment step above).

- The above steps will establish the PDU sessions which finally results in the creation of uesimtun interfaces.
```
uesimtun0: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1350
        inet 172.16.1.3  netmask 255.255.255.255  destination 172.16.1.3
        inet6 fe80::ca4f:95d4:d0f:9530  prefixlen 64  scopeid 0x20<link>
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 500  (UNSPEC)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4  bytes 192 (192.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

uesimtun1: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1350
        inet 172.16.2.3  netmask 255.255.255.255  destination 172.16.2.3
        inet6 fe80::3411:4ca1:1627:d23e  prefixlen 64  scopeid 0x20<link>
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 500  (UNSPEC)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4  bytes 192 (192.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```
Note: uesimtun0 for first slice and uesimtun1 for the second slice.

- Once the tunnel interfaces are created, any network applications can be used to send / receive traffic on the PDU sessions.

***Notes:***

- Free5gc subscriber Controller:
    * Exposes Restful APIs to talk to the Free5gc webui in the k8s native approach.
    * Used for populating the Free5gc subscriber database.
    * Will be replaced in the future by KNRC (K8s Native Restful Controller).
- MEC Application:
    * This repo has a demo mec application: which is nginx-rtmp server bundled with a video.
    * The user can use their own MEC application instead of the demo by modifying the EMCO script (deploy_slice_mecapp.sh)
- SDEWAN:
    * Link: sdewan(https://github.com/akraino-edge-stack/icn-sdwan)
- Most of the parameters of the NFs, Applications and the slice (namespace etc.,) can be modified in the shell scripts only, as the emcoctl scripts are made more generic.
- Modify the script to point to the target clusters' kubeconfig files.

***Links:***

- [Test Setup](test_setup.md)
- [Free5gc images](free5g.md)
- [sdewan](https://github.com/akraino-edge-stack/icn-sdwan)
