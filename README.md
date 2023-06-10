# CloudProject-Vagrant-Cloud
Cloud project Vagrant dummy cloud section repository..

## Prepare your envroiment
1. Install Ansible as a python dependency:
	```
	pip install -r requirements.txt
	```
2. Edit `config.sh` and `Vagrantfile.rb`, configuring them to match your infrastructure.
3. Generate your `Vagrantfile` by running `compile-Vagrantfile.sh`.
4. Generate your Ansible's `hosts.ini` by running `compile-ansible-hosts.sh`.
5. Generate a new ed25519 keypair under the `setup_kube` folder by running `generate-kube-keypair.sh`.
6. Bring up your infrastructure:
	```
	vagrant up
	```
7. Run every Ansible playbook under `playbooks` by running `playbook-run-all.sh`.
8. To build the Docker images, refer to the [CloudProject-Edge](https://github.com/LoZioo/CloudProject-Edge) repository.
9. To stop the cluster, run:
	```
	./playbook-run.sh cluster-teardown
	vagrant halt
	```

## Repo structure
- [scripts](scripts): ssh, tunneling and sftp bash scripts.
- [playbooks](playbooks): Ansible provision playbooks.
- [services](services): Docker images and the corresponding source code.
- [data](data): here you will find application specific runtime files.
- [setup_kube](setup_kube): Kubernetes installer.
- [config.sh](config.sh): configure it to match your infrastructure.
- [compile-Vagrantfile.sh](compile-Vagrantfile.sh): generate the `Vagrantfile` file.
- [compile-ansible-hosts.sh](compile-ansible-hosts.sh): generate the `hosts.ini` file.
- [playbook-run.sh](playbook-run.sh): run the specified Ansible playbook inside the [playbooks](playbooks) folder.
- [playbook-run-all.sh](playbook-run-all.sh): automatically run every Ansible playbook inside the [playbooks](playbooks) folder (fixed order).
- [generate-kube-keypair.sh](generate-kube-keypair.sh): Generate the needed keypair for Kubernetes setup.
- [kube-service-up.sh](kube-service-up.sh): Generate and run parameterized yml files inside the [infrastructure/build](infrastructure) folder (fixed order).
- [kube-service-down.sh](kube-service-down.sh): Delete the previously created resources.
- [requirements.txt](requirements.txt): Ansible python dependencies.

## Playbooks for provisioning
- `sync`: sync via rsync the entire local repository folder, including secrets, literally every file you have added in that folder so far, so be careful!
- `common`: install all the needed utilities.
- `boot-master`: start the Kubernetes control plane.
- `boot-workers`: start the Kubernetes workers.
- `cluster-teardown`: stops the Kubernetes cluster and remove the previously registered workers.
