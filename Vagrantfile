# VMs traits.
OS = "ubuntu/jammy64"
RAM = 2048
CPU = 2

M_NAME = "m"
W1_NAME = "w1"
W2_NAME = "w2"

M_IP =	"192.168.0.11"
W1_IP =	"192.168.0.12"
W2_IP =	"192.168.0.13"

INT_NET_NAME = "ds-net-0"

# Note: by default, a folder /vagrant on each VM is created and linked to the local working dir.
Vagrant.configure("2") do |config|
	config.vm.provider "virtualbox" do |vb|
	  # Display the VirtualBox GUI when booting the machine
	  # vb.gui = true

		vb.cpus = CPU
	  vb.memory = RAM
	end

	# Used OS.
	config.vm.box = OS

	# Provisioning script (executed as root).
	config.vm.provision :shell, path: "vagrant-provision.sh"

	config.vm.define M_NAME do |config|
		# Port forward on the natted network interface (6443 is kubernetes).
		config.vm.network :forwarded_port, guest: 6443, host: 6443, host_ip: "127.0.0.1"

		# Create a new network interface connected to the internal network INT_NET_NAME.
		config.vm.network "private_network", ip: M_IP, virtualbox__intnet: INT_NET_NAME
	end

	config.vm.define W1_NAME do |config|
		config.vm.network "private_network", ip: W1_IP, virtualbox__intnet: INT_NET_NAME
	end

	config.vm.define W2_NAME do |config|
		config.vm.network "private_network", ip: W2_IP, virtualbox__intnet: INT_NET_NAME
	end
end
