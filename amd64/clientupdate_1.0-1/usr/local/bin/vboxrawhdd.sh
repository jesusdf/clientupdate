#!/bin/bash
VBoxManage internalcommands createrawvmdk -filename "rawdisk.vmdk" -rawdisk $1
echo "Created rawdisk.vmdk"
