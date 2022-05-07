***Free5Gc Network Functions***
The free5GC is an open-source project for 5th generation (5G) mobile core networks.

**Steps to Build Free5Gc docker images**
1. Clone the free5gc-compose repo
```
mkdir -p free5gc
cd free5gc
git clone https://github.com/free5gc/free5gc-compose.git
cd free5gc-compose
git checkout 3298097bd53dedcb78e70ab05cc29546dec88ea6

```

2. Set the proxy configuration in the Makefile (optional step)
```
sed -i 's/.\/base$/.\/base\ \-\-build-arg\ http_proxy=<proxy-settings>\ \-\-build-arg\ https_proxy=<proxy-settings>/g' Makefile
```

3. Make the base image
```
sed -i '/^[^#]/ s/\(^.*&&\) make all$/\1 make nrf ausf udr udm nssf pcf amf smf upf/' base/Dockerfile
sed -i '/^[^#]/ s/\(^.*COPY.*webui$\)/#\ \1/' base/Dockerfile
sed -i '/^[^#]/ s/\(^.*COPY.*public$\)/#\ \1/' base/Dockerfile
make base
```

4. Build the other NFs
```
for i in nrf udr udm ausf nssf amf pcf  upf smf; do docker build -t free5gc-$i:3.0.6 ./nf_$i/ --build-arg http_proxy=<proxy-settings> --build-arg https_proxy=<proxy-settings> ; done
```

5. Build the webui image  (Add the proxy settings only if needed)
```
cd webui
sudo apt remove cmdtest
sudo apt remove yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update
sudo apt-get install -y nodejs yarn
git clone --recursive -b v3.0.6 -j `nproc` https://github.com/free5gc/free5gc.git
cd free5gc
make webconsole
cd ..
sed -i '/^[^#]/ s/\(^.*base.*$\)/#\ \1/' Dockerfile
sed -i '/^[^#]/ s/\(^.*COPY.*webconsole$\)/COPY \.\/free5gc\/webconsole\/bin\/webconsole \.\/webconsole\/webui /' Dockerfile
sed -i '/^[^#]/ s/\(^.*COPY.*public$\)/COPY \.\/free5gc\/webconsole\/public \.\/webconsole\/public/' Dockerfile
docker build -t free5gc-webui:3.0.6 ./ --build-arg http_proxy=<proxy-settings> --build-arg https_proxy=<proxy-settings>
```

6. Tag the images and push to the docker registry (DOCKER_REPO).

Link:
- [free5gc](https://www.free5gc.org/)
- [free5gc github](https://github.com/free5gc/free5gc)

