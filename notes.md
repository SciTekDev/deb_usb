

Now that the tools created the usb stick lets setup some scripts for creating some funcitonality out of the servers


we will want to setup one server as a storage device. 

i will be moving as many hard drives into that box as possible

the second one will have a couple disks, and should serve as the main web appliance

the third device will have an nvidia video card for gpu acclerated pods

we will be creating a k8s cluster with each of those three nodes.

northwoods 10.0.0.4 - DATA volumes - lots of ssd
eastwoods 10.0.0.6 - WEB/nvme drive
westwoods 10.0.0.8 - GPU/nvme drive

