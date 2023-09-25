#!/usr/bin/env bash

ssh -i $NFS_ID_RSA_FILE -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$NFS_IP '
  if [ -e /etc/exports ]; then
    echo nfs already configured &&\
    cat /etc/exports
  else
    echo setting up nfs &&\
    apt-get update && apt-get install -y nfs-kernel-server &&\
    mkdir -p /srv/default/root &&\
    chown -R nobody:nogroup /srv/default &&\
    echo "/srv/default 172.16.0.0/23(rw,sync,no_subtree_check,no_root_squash,fsid=0)" > /etc/exports &&\
    exportfs -a &&\
    systemctl restart nfs-kernel-server &&\
    echo OK
  fi
'
