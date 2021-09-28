#cloud-config

package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - python-pip

bootcmd:
  - test -z "$(blkid /dev/nvme1n1)" && mkfs -t ext4 -L data /dev/nvme1n1
  - mkdir -p /opt/data
  - mount /dev/nvme1n1 /opt/data

mounts:
  - ["/dev/nvme1n1", "/opt/data", "ext4", auto, "defaults,noexec,nofail"]

write_files:
  - content: |
      sleep 30
      curl -sS -H 'Content-Type: application/json' -X POST '127.0.0.1:4200/_sql' -d '{"stmt":"CREATE USER ${crate_user} WITH(password = '\''${crate_pass}'\'');"}'
      curl -sS -H 'Content-Type: application/json' -X POST '127.0.0.1:4200/_sql' -d '{"stmt":"GRANT ALL PRIVILEGES TO ${crate_user};"}'
    owner: root:root
    path: /opt/deployment/finish.sh
    permissions: "0755"
  - content: |
        path.data:
        - /opt/data
        auth.host_based.enabled: true
        auth:
          host_based:
            config:
              0:
                user: crate
                address: _local_
                method: trust
              99:
                method: password
        network.host: _site_, _local_
        cluster.name: ${crate_cluster_name}
        discovery.seed_hosts:
            ${crate_nodes_ips}
        cluster.initial_master_nodes:
            ${crate_nodes_ips}
        gateway.expected_nodes: ${crate_cluster_size}
        gateway.recover_after_nodes: ${crate_cluster_size}
    owner: root:root
    path: /etc/crate/crate.yml
    permissions: "0755"
  - content: |
      # Recommended memory settings for production:
      # - assign half of the OS memory to CrateDB
      #   (e.g. 26g, stay below ~30G to benefit from CompressedOops)
      # - disable swapping my setting bootstrap.mlockall in crate.yml
      # Run CRATE as this user ID and group ID
      #CRATE_USER=crate
      #CRATE_GROUP=crate
      # Heap Size (defaults to 256m min, 1g max)
      CRATE_HEAP_SIZE=${crate_heap_size}g
      # Maximum number of open files, defaults to 65535.
      # MAX_OPEN_FILES=65535
      # Maximum locked memory size. Set to "unlimited" if you use the
      # bootstrap.mlockall option in crate.yml. You must also set
      # CRATE_HEAP_SIZE.
      MAX_LOCKED_MEMORY=unlimited
      # Additional Java OPTS
      # CRATE_JAVA_OPTS=
      # Force the JVM to use IPv4 stack
      CRATE_USE_IPV4=true
    owner: root:root
    path: /etc/default/crate
    permissions: "0755"

runcmd:
  - chmod 777 /opt/data
  - wget https://cdn.crate.io/downloads/deb/DEB-GPG-KEY-crate
  - apt-key add DEB-GPG-KEY-crate
  - add-apt-repository "deb https://cdn.crate.io/downloads/deb/stable/ $(lsb_release -cs) main"
  - add-apt-repository "deb-src https://cdn.crate.io/downloads/deb/stable/ $(lsb_release -cs) main"
  - apt-get update -y
  - apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y crate
  - chown -R crate:crate /opt/data
  - chmod 700 /opt/data
  - bash /opt/deployment/finish.sh && rm -f /opt/deployment/finish.sh

final_message: "The system is finally up, after $UPTIME seconds"