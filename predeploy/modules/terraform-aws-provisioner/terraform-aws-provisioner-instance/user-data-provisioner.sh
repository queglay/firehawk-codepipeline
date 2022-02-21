#!/bin/bash

echo "Configure max revisions for codedeploy-agent..."

sed '$ d' /etc/codedeploy-agent/conf/codedeployagent.yml > /etc/codedeploy-agent/conf/temp.yml
echo ':max_revisions: 2' >> /etc/codedeploy-agent/conf/temp.yml
rm -f /etc/codedeploy-agent/conf/codedeployagent.yml
mv /etc/codedeploy-agent/conf/temp.yml /etc/codedeploy-agent/conf/codedeployagent.yml
service codedeploy-agent restart