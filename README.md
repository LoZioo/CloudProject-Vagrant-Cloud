# CloudProject-Cloud
Cloud project Cloud section repository.

## Prepare your envroiment
1. Install Ansible as a python dependency:
	```
	pip install -r requirements.txt
	```
2. Then:
	```
	source add-scripts-to-path.sh
	```
3. Edit `config.sh` and configure it to match your infrastructure.
4. Generate your Ansible's `hosts.ini` by running `compile-ansible-hosts.sh`.
5. Generate a new ed25519 keypair under the `setup_kube` folder by running `generate-kube-keypair.sh`.
6. Run every Ansible playbook under `playbooks` by running `playbook-run-all.sh`.
7. To build the Docker images, refer to the [CloudProject-Edge](https://github.com/LoZioo/CloudProject-Edge) repository.

## Repo structure
- [scripts](scripts): ssh, tunneling and sftp bash scripts.
- [playbooks](playbooks): Ansible provision playbooks.
- [services](services): Docker images and the corresponding source code.
- [data](data): here you will find application specific runtime files.
- [setup_kube](setup_kube): Kubernetes installer.
- [add-scripts-to-path.sh](add-scripts-to-path.sh): add every script under [scripts](scripts) to `$PATH`.
- [config.sh](config.sh): configure it to match your infrastructure.
- [compile-ansible-hosts.sh](compile-ansible-hosts.sh): generate the `hosts.ini` file.
- [playbook-run.sh](playbook-run.sh): run the specified Ansible playbook inside the [playbooks](playbooks) folder.
- [playbook-run-all.sh](playbook-run-all.sh): automatically run every Ansible playbook inside the [playbooks](playbooks) folder (fixed order).
- [generate-kube-keypair.sh](generate-kube-keypair.sh): Generate the needed keypair for Kubernetes setup.
- [requirements.txt](requirements.txt): Ansible python dependencies.

## Playbooks for provisioning
- `sync`: sync via rsync the entire local repository folder, including secrets, literally every file you have added in that folder so far, so be careful!
- `common`: install all the needed utilities.
- `boot-master`: start the Kubernetes control plane.
- `boot-workers`: start the Kubernetes workers.
