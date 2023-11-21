#!/bin/bash

m_NS="catchup"
mPATH_CD_FILES="/Users/nilson/Workspace/Pulse/DevOps/cd-files/master/$m_NS"
m_APP=$(ls $mPATH_CD_FILES | sort | grep -v .yml | grep -v applications | grep -v gateway | grep -v virtualservice | sed 's/.*/&/;$!s/$/ /' | tr -d '\n')

for i in $m_APP;
do
echo $i

if [ -f "$mPATH_CD_FILES/$i/scaleobject.yaml" ]; then
    m_MAX=$(cat $mPATH_CD_FILES/$i/scaleobject.yaml | grep maxReplicaCount | awk '{print $2}')
    m_MIN=$(cat $mPATH_CD_FILES/$i/scaleobject.yaml | grep minReplicaCount | awk '{print $2}')
    m_LIST=$(echo $i >> list.txt)

cat << EOF > $mPATH_CD_FILES/$i/scaleobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: $i-prod
spec:
  cooldownPeriod: 30
  maxReplicaCount: $m_MAX
  minReplicaCount: $m_MIN
  pollingInterval: 30
  scaleTargetRef:
    name: $i-prod
  triggers:
    - type: prometheus
      metadata:
        metricName: mem-percent-$i-prod
        query: sum(container_memory_usage_bytes{container=~"$i-prod-.*", pod=~"$i-prod-.*", namespace="$m_NS-pro", service="kube-prometheus-stack-kubelet"}) / sum(kube_pod_container_resource_limits{resource="memory", pod=~"$i-prod-.*", namespace="$m_NS-pro", container=~"$i-prod-.*", service="helm-kube-prometheus-stack-kube-state-metrics"}) * 100
        serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
        threshold: '70'
EOF

else 
  echo "Arquivo $mPATH_CD_FILES/$i/scaleobject.yaml não encontrado"
fi
done

echo "SEMANTICAL COMMITS AND GITFLOW"
echo " "
echo "Gerando Texto para Branch: "
echo -e "hotfix-AZDE-17042-Adjust-HPA-in-squad-$m_NS"
echo " "
echo "Gerando Mensagem de Commit: "
echo -e "fix(devops): [AZDE-17042] - Adjust in ScaleObejcts for Squad $m_NS \n
- Aplications:
`<list.txt`"

rm -f list.txt