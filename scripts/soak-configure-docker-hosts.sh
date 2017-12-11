
# Transfer the script to populate the HostGroup and  Activation keys.
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no soak-docker-client-setup.sh root@"${SATELLITE_SERVER_HOSTNAME}":/root/

# Run the script to populate the HostGroup and  Activation keys.
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"${SATELLITE_SERVER_HOSTNAME}" /root/soak-docker-client-setup.sh

# Setup the docker host, for things like networking/docker0
# Ensure the 10gnic being passed is a physical interface and not a Bridge.
ansible-playbook --private-key conf/id_rsa_soak -i conf/hosts.ini playbooks/satellite/docker-host.yaml

# Downloads the "r7perfsat" docker image and starts containers depending upon the DOCKER_HOST_COUNT
ansible-playbook --private-key conf/id_rsa_soak -i conf/hosts.ini playbooks/satellite/docker-tierup.yaml

# Changes for Satellite6.3
#bootstrap_org_name: "Default Organization"
if [[ "${SATELLITE_VERSION}" == "6.3" ]]; then
    sed -i 's/bootstrap_org_name: "Default Organization"/bootstrap_org_name: "Default_Organization"/' playbooks/satellite/roles/client-scripts/files/clients.yaml.j2
fi

# skip the foreman part via bootsrap.py
sed -i 's/bootstrap_additional_args: "--force"/bootstrap_additional_args: "--force --skip foreman"/' playbooks/satellite/roles/client-scripts/files/clients.yaml.j2

# Update the tags
sed -i 's/tags: "untagged,REGTIMEOUTTWEAK,REG,DOWNGRADE,REM"/tags: "untagged,REGTIMEOUTTWEAK,REG,REM,KAT,PUP"/' playbooks/tests/registrations.yaml

# Would register the containers depending upon the COUNT to sat6 via the bootstrap.py script.
ansible-playbook --forks 100 -i conf/hosts.ini playbooks/tests/registrations.yaml -e "size=${DOCKER_HOST_COUNT} resting=0"
