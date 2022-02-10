#cloud-config

package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - git

bootcmd:
  - test -z "$(blkid /dev/nvme1n1)" && mkfs -t xfs -L data /dev/nvme1n1
  - mkdir -m 777 /opt/data
  - mount LABEL=data /opt/data

mounts:
  - ["LABEL=data", "/opt/data", "xfs", "defaults,noexec,nofail"]

commands:
  - git clone git@github.com:proddata/nodeIngestBench.git

final_message: "The system is finally up, after $UPTIME seconds"
