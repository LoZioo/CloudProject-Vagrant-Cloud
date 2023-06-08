# Passi da compiere per installare kubernetes su un gruppo di host (Debian o derivati) e rendere questi un cluster

## Concetti

Questi script risiedono in origine in una directory, p.es. `setup_kube`,
sul cliente di sviluppo;
una directory con lo stesso nome, p.es. `setup_kube`, dovrebbe esistere su
ciascuno degli host-nodi del cluster, nella rispettiva _home directory_;
la directory su ciascun host-nodo è destinata (v. sotto) a contenere una
copia dei file di installazione in questa directory sul cliente di sviluppo.

NB: il cliente &ldquo;di sviluppo&rdquo; (cioè quello su cui si modificano i file `*.sh`, `*.yaml` e 
`*.json` di questa directory)
potrebbe essere il vs. PC, ma anche uno dei nodi-host.

1. Configurare le variabili in `./config.sh`, in particolare nomi e IP
   dei nodi e nome di un utente `$KUSER` che deve esistere ed essere
   _sudoer_ su ciascuno dei nodi.

1. Accertarsi che dal cliente e dal futuro master del cluster si possa eseguire ssh **senza**
   password (mediante chiave pubblica/privata) per `$KUSER` verso **tutti** i nodi del cluster.

   Ciò si può ottenere eseguendo sul cliente (che deve già avere una propria chiave privata
   ssh, ottenuta con `ssh-keygen -t rsa`) il comando `ssh-copy-id $KUSER@nodo`,
   per ciascun `nodo`, solo una volta.

   Se gli host del cluster sono VM generate mediante gli script nelle sottodirectory
   `aws`, `vagrant`, etc., si possono impiegare altri strumenti (`ssh -i ssh_key.pem`,
   `vagrant ssh`,..., v. nelle sottodirectory).

   **NB:** A volte nella directory ~/.ssh restano delle socket "stale" chiamate `socket-$USER@REMOTE-IP:22`;
   occorre eliminarle o `ssh` e `rsync` si bloccheranno.

1. Distribuire gli script agli host/nodi (elencati in config.sh), con il
   comando (da shell, in questa directory):
   ```bash
   ./upload_scripts.sh
   ```
   sui vari host i file si troveranno nella home dell'utente, `/home/$KUSER`,
   in una directory chiamata (tipicamente `setup_kube/`) come quella del cliente in cui si trovano gli
   script da caricare; questo passo di upload andrà ripetuto ogni volta che un file cambia.

   `./upload_scripts.sh` mostra, nel proprio output, quali saranno i nomi dell'utente e di questa directory su ciascun host.

   `./upload_scripts.sh -n` e `./upload_scripts.sh --dry-run` mostrano quali file verrebbero trasferiti
   e dove, senza trasferirli; evidenziano anche problemi di trasferimento della chiave ssh verso
   i server.

Con i precedenti passi (1,2,3), la parte di rilievo di questa directory viene distribuita a tutti gli host del cluster k8s da creare (o aggiornare).

***

I passi da qui in poi vanno compiuti su ogni host che si vuole fare
entrare nel cluster, operando da super-user.

NB: tutti gli script *.sh dovrebbero essere "idempotenti", cioè non alterare lo stato dell'host dopo la prima esecuzione; in altre parole: non dovrebbe succedere niente di male se si esegue uno script più di una volta.

***

4. Entrare nell'host e operare come super-user, ma da dentro la
   directory, sia `setup_kube`, dell'utente `$KUSER:
   ```bash
   sudo -i
   cd /home/$KUSER/setup_kube
   ```

1. Si esegua una sola volta (poi non servirà, anche dopo reboot, salvo
   che si voglia aggiornare k8s con i suoi componenti e dipendenze):
   ```bash
   ./install_kube.sh
   ```

1. Si prepara l'ambiente per k8s, eseguendo:
   ```bash
   ./reset_kube.sh
   ```
   * non è chiaro se ciò serva appena il sistema viene su dal boot, ma è consigliato

   * inoltre, si esegue su un worker, per farlo uscire dal cluster, e sul master, 
     per distruggere il cluster

     (in effetti `reset_kube.sh` completo servirebbe solo per il master (esegue `kubeadm reset -f`
che non serve a un worker, ma non gli crea problemi).

* Più comodamente, da un nodo o dal client, dopo avere eseguito `. setenv.sh`, 
  si può effettuare il reset di tutto il cluster con:
   ```bash
   all_reset
   ```

***
A questo punto si può mettere su il cluster:
1. sul futuro nodo master, per far partire il cluster k8s:
   ```bash
   ./boot_master.sh
   ```

1. su ciascun nodo worker, per unirlo al cluster eseguire:
   ```bash
   ./boot_worker.sh
   ```
***

* oppure, più comodamente, dal nodo destinato a diventare master, dopo avere eseguito `. setenv.sh`,
  si può avviare **tutto** il cluster:
   ```bash
   all_boot [-q]
   ```
   o, da un cliente o nodo diverso dal master desiderato, dopo avere eseguito `. setenv.sh`, 
   noto del master:
   ```bash
   all_boot master [-q]
   ```

* anche il client potrà eseguire comandi `kubectl` sul cluster dopo `all_boot_master` o, comunque, dopo `get_kconfig`

***

Per il &ldquo;tear-down&rdquo; di un cluster, occorre prima svuotare e chiudere i worker, poi il master,
  v. https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down

Per i nostri esperimenti, un po' alla buona, ci si può limitare a:

* per eliminare un worker dal cluster, `sudo ./reset_kube.sh` sul worker

* per reintegrare il worker nel cluster, `sudo ./boot_worker.sh` sul worker

  (ma occorre attendere che il master si accorga che il worker è uscito, prima di reintegrarlo)

* per chiudere un cluster, eliminare tutti i worker, poi `sudo ./reset_kube.sh` sul master, oppure, dal
  master, sempre che si sia eseguito `. setenv.sh`:
  ```
  all_reset [-q]
  ```
  che si può invocare anche da un client, purché `all_boot` fosse stato eseguito sul client stesso,
  oppure, sul client, si sia eseguito con successo `get_kconfig`

* dopo aver chiuso il cluster (e avere atteso a sufficienza) lo si può ripristinare come quando lo si è avviato la prima volta.

***
## Operare contemporaneamente sugli host del cluster

Come spiegato prima, degli script utili a questo scopo si installano con:
```
. ./set_env.sh
```
Ma, forse, è ancora più efficace `tmux`, v.
https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md#running-commands-in-parallel-with-tmux

***
## Sensitive files
```
K8S_DELETE="\
/var/lib/cni/networks \
/var/lib/cni/results \
"
```
```
K8S_EMPTY="\
/etc/kubernetes/manifests \
/etc/kubernetes/pki \
/etc/cni/net.d \
/var/lib/dockershim \
/var/lib/etcd \
/var/lib/kubelet \
"
```
```
K8S_FILES_MASTER="\
/etc/kubernetes/admin.conf \
/etc/kubernetes/kubelet.conf \
/etc/kubernetes/controller-manager.conf \
/etc/kubernetes/scheduler.conf \
/etc/kubernetes/bootstrap-kubelet.conf \
/var/run/kubernetes \
"
```
```
K8S_NODELETE="\
/var/run/containerd \
/var/run/calico \
/var/lib/containerd \
/var/lib/calico \
"
```
