#!/bin/bash

mCDFILES="/Users/nilson/Workspace/Pulse/DevOps/cd-files/master"
mLIST=$(find $mCDFILES -name '*.yaml' -type f -exec grep -rli '\-javaagent:/deployments/agent/datadog-agent/dd-java-agent.jar' {} \;)

for i in $mLIST;
do
    mCONTAINER=$(echo $i | awk -F "/" '{print $10}')
    kubectl set env deploy --local -f $i -c $mCONTAINER-prod-container  -e DD_APPSEC_ENABLED=true -e DD_IAST_ENABLED=true -o yaml > /tmp/$mCONTAINER.yaml  && cat /tmp/$mCONTAINER.yaml > $i
done