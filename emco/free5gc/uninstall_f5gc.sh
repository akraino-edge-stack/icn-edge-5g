#! /bin/bash

WAIT=10
EMCOCTL=emcoctl

echo "Uninstalling the Free5gc using EMCO..."
${EMCOCTL} --config emco-cfg.yaml delete -f f5gc-subscribe.yaml -v values.yaml -w 20
sleep 1
${EMCOCTL} --config emco-cfg.yaml delete -f f5gc-subscribe.yaml -v values.yaml -w $WAIT


${EMCOCTL} --config emco-cfg.yaml delete -f sdewan-crd-deploy.yaml -v values.yaml -w 10
sleep 1
${EMCOCTL} --config emco-cfg.yaml delete -f sdewan-crd-deploy.yaml -v values.yaml -w $WAIT

${EMCOCTL} --config emco-cfg.yaml delete -f slice_deploy.yaml -v values.yaml -w 80
sleep 10
${EMCOCTL} --config emco-cfg.yaml delete -f slice_deploy.yaml -v values.yaml -w $WAIT
sleep 5

${EMCOCTL} --config emco-cfg.yaml delete -f common_deploy.yaml -v values.yaml -w 20
sleep 5
${EMCOCTL} --config emco-cfg.yaml delete -f common_deploy.yaml -v values.yaml -w $WAIT
sleep 5

${EMCOCTL} --config emco-cfg.yaml delete -f cert-manager-deploy.yaml -v values.yaml -w $WAIT
sleep 30
${EMCOCTL} --config emco-cfg.yaml delete -f cert-manager-deploy.yaml -v values.yaml -w $WAIT
sleep 5

${EMCOCTL} --config emco-cfg.yaml delete -f logical_cloud.yaml -v values.yaml -w 10
sleep 5
${EMCOCTL} --config emco-cfg.yaml delete -f logical_cloud.yaml -v values.yaml -w $WAIT
sleep 10

#${EMCOCTL} --config emco-cfg.yaml delete -f monitor.yaml -v values.yaml -w $WAIT
sleep 1
#${EMCOCTL} --config emco-cfg.yaml delete -f monitor.yaml -v values.yaml -w $WAIT

${EMCOCTL} --config emco-cfg.yaml delete -f prerequisites.yaml -v values.yaml -w $WAIT
${EMCOCTL} --config emco-cfg.yaml delete -f prerequisites.yaml -v values.yaml -w $WAIT

#echo "Clean up the chart tgz files"
#rm -rf ../../Charts/*.tgz

