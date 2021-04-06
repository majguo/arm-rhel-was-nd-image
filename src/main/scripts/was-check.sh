#!/bin/bash

#      Copyright (c) Microsoft Corporation.
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

echo "Checking at + $(date)" > /var/log/cloud-init-was.log

# TODO: Removed later. Only for simulating the time used for entitlement check and applicatoin patch.
sleep 20

# Read custom data from ovf-env.xml
customData=`xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" /var/lib/waagent/ovf-env.xml`
IFS=',' read -r -a ibmIdCredentials <<< "$(echo $customData | base64 -d)"

# TODO: Modified later per the real code on how to do entitlement check and application patch.
if [ ${#ibmIdCredentials[@]} -eq 2 ] && [ ${ibmIdCredentials[0]} = entitled@sample.com ] && [ ${ibmIdCredentials[1]} = sampleSecret ]; then
    echo "Entitled" >> /var/log/cloud-init-was.log
else
    # Remove WAS installation
    /datadrive/IBM/InstallationManager/V1.9/eclipse/tools/imcl uninstall com.ibm.websphere.ND.v90_9.0.5001.20190828_0616 com.ibm.java.jdk.v8_8.0.5040.20190808_0919 -installationDirectory /datadrive/IBM/WebSphere/ND/V9/
    echo "Unentitled" >> /var/log/cloud-init-was.log
fi

# Scrub the custom data which contains sensitive information.
if grep -q "CustomData" /var/lib/waagent/ovf-env.xml; then
    sed -i "s/${customData}/REDACTED/g" /var/lib/waagent/ovf-env.xml
fi
