# VMs traits.
OS = "ubuntu/jammy64"
RAM = 2048
CPU = 2
BRIDGE_INTERFACE = "enp9s0"

M_NAME = "m"
W1_NAME = "w1"
W2_NAME = "w2"

# Note: by default, a folder /vagrant on each VM is created and linked to the local working dir.
Vagrant.configure("2") do |config|
	config.vm.provider "virtualbox" do |vb|
	  # Display the VirtualBox GUI while booting.
	  # vb.gui = true

		vb.cpus = CPU
	  vb.memory = RAM
	end

	# Used OS.
	config.vm.box = OS

	# Provisioning script (executed as root).
	config.vm.provision :shell, path: "vagrant-provision.sh"

	config.vm.define M_NAME do |config|
		config.vm.hostname = "kube-" + M_NAME

		# Create a new network interface bridged to the physical network.
		config.vm.network "public_network", bridge: BRIDGE_INTERFACE, ip: M_IP
	end

	config.vm.define W1_NAME do |config|
		config.vm.hostname = "kube-" + W1_NAME
		config.vm.network "public_network", bridge: BRIDGE_INTERFACE, ip: W1_IP
	end

	config.vm.define W2_NAME do |config|
		config.vm.hostname = "kube-" + W2_NAME
		config.vm.network "public_network", bridge: BRIDGE_INTERFACE, ip: W2_IP
	end
end
