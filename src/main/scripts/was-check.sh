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

# Get tWAS installation properties
source /datadrive/virtualimage.properties

echo "Checking at + $(date)" > /var/log/cloud-init-was.log

# Read custom data from ovf-env.xml
customData=`xmllint --xpath "//*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" /var/lib/waagent/ovf-env.xml`
IFS=',' read -r -a ibmIdCredentials <<< "$(echo $customData | base64 -d)"

# Check whether IBMid is entitled or not
entitled=false
if [ ${#ibmIdCredentials[@]} -eq 2 ]; then
    userName=${ibmIdCredentials[0]}
    password=${ibmIdCredentials[1]}
    
    ${IM_INSTALL_DIRECTORY}/eclipse/tools/imutilsc saveCredential -secureStorageFile storage_file \
        -userName "$userName" -userPassword "$password" -passportAdvantage
    if [ $? -eq 0 ]; then
        output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imcl listAvailablePackages -cPA -secureStorageFile storage_file)
        echo $output | grep -q "$WAS_ND_VERSION_ENTITLED" && entitled=true
    else
        echo "Cannot connect to Passport Advantage." >> /var/log/cloud-init-was.log
    fi
else
    echo "Invalid input format." >> /var/log/cloud-init-was.log
fi

if [ ${entitled} = true ]; then
    # Update all packages for the entitled user
    output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imcl updateAll -repositories "$REPOSITORY_URL" \
        -acceptLicense -log log_file -installFixes none -secureStorageFile storage_file -preferences $SSL_PREF,$DOWNLOAD_PREF -showProgress)
    echo "$output" >> /var/log/cloud-init-was.log
    echo "Entitled" >> /var/log/cloud-init-was.log
else
    # Remove tWAS installation for the un-entitled user
    output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imcl uninstall "$WAS_ND_TRADITIONAL" "$IBM_JAVA_SDK" -installationDirectory ${WAS_ND_INSTALL_DIRECTORY})
    echo "$output" >> /var/log/cloud-init-was.log
    rm -rf /datadrive/IBM && rm -rf /datadrive/virtualimage.properties
    echo "Unentitled" >> /var/log/cloud-init-was.log
fi

# Scrub the custom data from files which contain sensitive information
if grep -q "CustomData" /var/lib/waagent/ovf-env.xml; then
    sed -i "s/${customData}/REDACTED/g" /var/lib/waagent/ovf-env.xml
    sed -i "s/Unhandled non-multipart (text\/x-not-multipart) userdata: 'b'.*'...'/Unhandled non-multipart (text\/x-not-multipart) userdata: 'b'REDACTED'...'/g" /var/log/cloud-init.log
    sed -i "s/Unhandled non-multipart (text\/x-not-multipart) userdata: 'b'.*'...'/Unhandled non-multipart (text\/x-not-multipart) userdata: 'b'REDACTED'...'/g" /var/log/cloud-init-output.log
fi

# Remove temporary files
rm -rf storage_file && rm -rf log_file
