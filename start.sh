set_git(){
    if (! git --version ); then
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests git;
    fi
}
set_cert(){
# Check and update ca-certificates
if (! update-ca-certificates ); then 
    apt-get install -y -qq --no-install-recommends --no-install-suggests ca-certificates;
fi
}

set_curl(){
# Check your `curl` version
if (! curl --version ); then 
    apt-get install -y -qq --no-install-recommends --no-install-suggests curl;
fi
}

# set_nvm(){
    # set_cert
    # git clone https://github.com/nvm-sh/nvm.git .nvm
    # cd .nvm
    # git checkout v0.38.0
    # export NVM_DIR=$PWD/.nvm 
    # [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    # [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion”
# }

set_gradlew(){
	set_cert
  apt-get install -y -qq --no-install-recommends --no-install-suggests wget unzip
  wget https://services.gradle.org/distributions/gradle-5.5.1-all.zip && unzip -d gradle gradle-5.5.1-all.zip
  # find ~/.gradle -type f -name "*.lock" -delete
	# rm -rf .gradle/caches
}

# nvm install node
# $  wget https://github.com/apache/openwhisk-cli/releases/download/1.2.0/OpenWhisk_CLI-1.2.0-linux-amd64.tgz && tar -xvzf OpenWhisk_CLI-1.2.0-linux-amd64.tgz
# $  export PATH=”$PWD:$PATH”
# Install xdg-open by npm
# $  npm install --global opn

set_mycluster(){
# create a default mycluster.yaml for a single worker node
# https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy
echo 'affinity:
  enabled: false
toleration:
  enabled: false
invoker:
  options: "-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false"
' > mycluster.yaml
# -------- or ----------
# echo 'whisk:
#   ingress:
#     type: NodePort
#     apiHostName: localhost
#     apiHostPort: 31001
#     useInternally: false
# nginx:
#   httpsNodePort: 31001
# # disable affinity
# affinity:
#   enabled: false
# toleration:
#   enabled: false
# invoker:
#   options: "-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false"
#   # must use KCF as kind uses containerd as its container runtime
#   containerFactory:
#     impl: "kubernetes"
# ' > mycluster.yaml
}

set_helm3(){
if ( ! helm version ); then 
	set_cert
	set_curl
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh
	rm get_helm.sh;
	# -------- or ----------
	# download 
	# tar -zxvf helm-v3.0.0-linux-amd64.tar.gz
	# mkdir /usr/local/bin/helm
	# mv linux-amd64/helm /usr/local/bin/helm
	# -------- or ----------
	# curl https://baltocdn.com/helm/signing.asc | apt-key add -
	# apt-get install apt-transport-https --yes
	# echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
	# apt-get update
	# apt-get install helm
	# -------- or ----------
	# set_git
	# git clone https://github.com/helm/helm.git
	# cd helm
	# set_make
	# make
fi
}

set_docker(){
# ubuntu 20.04
if ( ! docker --version ); then apt install docker.io -y; fi
if ( ! systemctl status docker ); then systemctl enable docker; systemctl start docker; fi
}

set_k8s(){
# install k8s Kubernetes version 1.19+, kubelet's hairpin-mode must not be none: Endpoints of Kubernetes services must be able to loopback to themselves

# '	# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# 	set_curl;
# 	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl";
# 	chmod +x kubectl;
# 	mkdir -p ~/.local/bin/kubectl;
# 	mv ./kubectl ~/.local/bin/kubectl;
# 	# and then add ~/.local/bin/kubectl to $PATH
# '

# https://www.howtoforge.com/tutorial/how-to-install-kubernetes-on-ubuntu/
# add a signing key in you on Ubuntu, adding a subscription key
apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests gnupg apt-transport-https
set_curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add # curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

if ( ! kubectl version --client ); then 
	apt-get update && apt-get -y upgrade && apt-get install software-properties-common python-software-properties # apt-get install apt-file && apt-file update -y # apt-file search add-apt-repository
	apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" # sed -i -e '50d' /etc/apt/sources.list # sed -i '50s/\(.*\)/#\1/' /etc/apt/sources.list
	apt-get update && apt-get -y upgrade && apt-get install kubeadm kubelet kubectl # apt update && apt install -y kubeadm kubelet kubectl
	apt-mark hold kubeadm kubelet kubectl;
fi

# init k8s cluster
cidr=10.244.0.0/16
kubeadm init --pod-network-cidr=$cidr --apiserver-advertise-address=10.0.15.10 #--kubernetes-version "1.21.0"
kubeadm version
}

deploy_k8s(){
# In order to set up the Kubernetes Linux servers, disabling the swap memory on each server
swapon -s
swapoff –a

# set as the master node
if [ ! -n "$master_node" ]; then read -p "Your master_node Name? :" master_node; fi
hostnamectl set-hostname $master_node
cidr=10.244.0.0/16
kubeadm init --pod-network-cidr=$cidr


# 'kubernets-master:~$ 
#     mkdir -p $HOME/.kube
#     cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#     chown $(id -u):$(id -g) $HOME/.kube/config

# https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
# '

# kubectl apply -f <>
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# kubectl get pods --all-namespaces

# '
# # set as worker
# hostnamectl set-hostname w1
# kubeadm join 10.0.15.10:6443 --token daync8.5dcgj6c6xc7l8hay --discovery-token-ca-cert-hash sha256:65a3e69531d323c335613dea1e498656236bba22e6cf3d5c54b21d744ef97dcd
# kubeadm join --discovery-token abcdef.1234567890abcdef --discovery token-ca-cert-hash sha256:1234..cdef 1.2.3.4:6443
# kubectl get nodes
# '
}

set_kind_config(){
# for multi-node cluster
echo '# two node (one workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    # listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
    # protocol: udp # Optional, defaults to tcp
- role: worker
  extraPortMappings:
    - hostPort: 31001
      containerPort: 31001
' > kind-example-config.yaml
}

set_kind(){
# not recommended for production deployments of OpenWhisk
# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-kind.md
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind
}

redeploy(){
# k8s image build, redeploying
# https://kind.sigs.k8s.io/docs/user/quick-start/#building-images
# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-kind.md
# https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#prerequisites-kubernetes-and-helm
# in openwhisk dir
bin/wskdev controller -b
./gradlew distDocker
set_stanza
helm upgrade owdev ./helm/openwhisk -n openwhisk -f mycluster.yaml # using helm
kind load docker-image whisk/controller # using kind
}

# (set_kind_config)
create_cluster(){
# ensure that Kubernetes is cloned in $(env PATH)/src/k8s.io/kubernetes
if [ ! -n "$cluster_name" ]; then read -p "Your K8s Cluster Name? :" cluster_name; fi
kind create cluster --name $cluster_name # --image=... # --wait 30s #--config kind-example-config.yaml
kind get clusters
kubectl cluster-info --context kind-$cluster_name

if [ ! -n "$docker_image_name_1" ]; then read -p "Your docker_image Name? :" docker_image_name_1; fi
kind load docker-image $docker_image_name_1 --name $cluster_name
# kind load docker-image $docker_image_name_1 $docker_image_name_2 --name $cluster_name
set_stanza

# 'helm install'
# kubectl apply -f $my-manifest-using-my-image:$image_version
# 'kind delete cluster'
kind export logs $PWD --name $cluster_name

# must use the KubernetesContainerFactory when running OpenWhisk on kind
}

set_openwhisk(){
set_k8s

set_helm3

# add a chart repository
helm repo add openwhisk https://openwhisk.apache.org/charts
helm repo update
set_mycluster

deploy_k8s

if [ ! -n "$owdev" ]; then read -p "Your Deployment Name? :" owdev; fi
if [ ! -n "$openwhisk" ]; then read -p "Your Namespace Name? :" openwhisk; fi
helm install $owdev openwhisk/openwhisk -n $openwhisk --create-namespace -f mycluster.yaml
# -------- or ---------
# git clone https://github.com/apache/openwhisk-deploy-kube.git
# cd openwhisk-deploy-kube 
# set_mycluster
# helm install $owdev ./helm/openwhisk -n $openwhisk --create-namespace -f mycluster.yaml

echo 'check if install-packages is `Completed`'
helm status $owdev -n $openwhisk
kubectl get pods -n openwhisk --watch

# default test
# helm test $owdev -n $openwhisk
}

deploy_openwhisk(){
	Deploy OpenWhisk with Helm
	https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#deploy-with-helm

# 	https://github.com/apache/openwhisk
  git clone https://github.com/apache/openwhisk-deploy-kube.git
# 	set $OPENWHISK_HOME to its top-level directory
  cd openwhisk && export OPENWHISK_HOME=$PWD
  
  set_openwhisk
}

set_wsk_cli(){
brew update
brew install wsk
# suppress certificate checking
wsk -i
}

config_wsk_cli(){
	# External to the Kubernetes cluster, using wsk cli
	set_wsk_cli

	# https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#configure-the-wsk-cli
  if [ ! -n "$apiHostName" ]; then read -p "Your apiHostName? e.g. localhost :" apiHostName; fi
  if [ ! -n "$apiHostPort" ]; then read -p "Your apiHostPort? e.g. 31001 :" apiHostPort; fi
	WHISK_SERVER=$apiHostName:$apiHostPort
	WHISK_AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
	wsk property set --apihost $WHISK_SERVER --auth $WHISK_AUTH --namespace guest

	# WHISK_SERVER=`wsk property get --apihost`
	# WHISK_AUTH=`wsk property get --auth`

	# wsk cli stores the properties set in ~/.wskprops by default
}

set_pyfile(){
echo '
def main(dict):
    return {"greeting": "greeting"}
' > hello.py
}

set_manifest(){
echo '		packages:
		    default:
		        actions:
		            helloPy:
		                function: hello.py
                		runtime: python:3' > manifest.yaml
}

invoke_wsk_cli(){
# 	set_pyfile

# 	https://github.com/apache/openwhisk/blob/master/docs/actions.md

# 	wsk action create helloPy hello.py
# 	wsk action invoke helloPy --result --param name World
}

set_stanza(){
# If you are using Kubernetes in Docker, it is straightforward to deploy local images by adding a stanza to your mycluster.yaml. 
echo '
controller:
  imageName: "whisk/controller"
  imageTag: "latest"' >> mycluster.yaml
}

clean_up(){
	helm uninstall $owdev -n $openwhisk --keep-history
}
