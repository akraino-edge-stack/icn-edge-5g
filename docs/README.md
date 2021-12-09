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
- The slices are deployed from the cluster-A which has the EMCO installed.

****2.1 First Slice:****
- The first slice is deployed in the default namespace. (this will be moved to its own namespace later)
- the script "deploy_f5gc.sh" and the major functions are as below,
    * deploys the monitor
    * Create the required logical clouds.
    * Deploys the free5gc NFs.
    * Deploys the SDEWAN CRD Controller.
    * Deploys the Free5gc subscriber controller and adds an entry to the data-base.
Note: The parameters of the network slice NFs can be controlled by modifying the script.
```
cd emco/free5gc
./deploy_f5gc.sh
```
Here is the output of the above script
```
Deploying the Free5gc using EMCO...
-----------------------------------------------------------------------
Instantiating App: emco-monitor ...Done, successful.
-----------------------------------------------------------------------
Creating Logical Clouds ...
Instantiating Logical Cloud: sdewan-manager ..Done, successful.
Instantiating Logical Cloud: cert-manager ..Done, successful.
Instantiating Logical Cloud: httpcrd ..Done, successful.
-----------------------------------------------------------------------
Instantiating App: certificate-manager .....Done, successful.
-----------------------------------------------------------------------
Instantiating App: free5gc default slice_0 ..................Done, successful.
-----------------------------------------------------------------------
Instantiating App: sdewan-crd-controller ..Done, successful.
-----------------------------------------------------------------------
Instantiating App: f5gc-subscriber-controller ...................Done, successful.
```
The slice deployment is depicted as below,
<img src=slice_NF_Deployment.png>

****2.2 Second Slice:****
- The second slice is deployed in the slice namespace. 
- the script "deploy_f5gc.sh" and the major functions are as below,
    * Create the required logical clouds.
    * Deploys the free5gc NFs for the second slice in the slice namespace.
    * Deploys the demo MEC Application.
    * Installs the traffic redirection rules to redirect the traffic to the local demo MEC application.
Note: The parameters of the network slice NFs can be controlled by modifying the script.
```
./deploy_slice_mecapp.sh
```

The output of the above is as below:
```
Deploying the MEC App using EMCO...
-----------------------------------------------------------------------
Creating Logical Clouds ...
Instantiating Logical Cloud: prioslice ..Done, successful.
-----------------------------------------------------------------------
Deploying a new slice ...
Instantiating App: free5gc prio slice_1 ..........Done, successful.
-----------------------------------------------------------------------
Deploying mecApp and Installing Traffic Steering Rules ...
Instantiating App: MEC App slice_1 with Traffic steering Rules ..Done, successful.
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
