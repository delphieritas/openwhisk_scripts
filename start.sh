set_git(){
    if (! git --version ); then
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests git;
    fi
}
set_cert(){
# Check and update ca-certificates
if (! update-ca-certificates ); then 
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests ca-certificates;
fi
}
set_curl(){
# Check your `curl` version
if (! curl --version ); then 
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests curl;
fi
}
set_unzip(){
if (! unzip --version ); then 
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests unzip;
fi
}
set_wget(){
if (! wget --version ); then 
    apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests wget;
fi
}
set_helm3(){
# v3.2.0++
if ( ! helm version ); then 
    set_cert
    set_curl 

    mkdir helm3
    cd helm3
    curl -LO https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz
    tar -zxvf helm-v3.7.0-linux-amd64.tar.gz
    chmod +x ./helm
    export PATH=$PATH:$PWD
    cd ..
fi
}

set_kind_config(){
    https://raw.githubusercontent.com/kubernetes-sigs/kind/main/site/content/docs/user/kind-example-config.yaml
    https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy/kind/kind-cluster.yaml
    # for multi-node cluster
    echo '# three node (two workers) cluster config
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
## add one more control-plane node & worker
# - role: control-plane
# - role: worker
' > kind-example-config.yaml
}

set_kind(){
    # not recommended for production deployments of OpenWhisk
    # https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-kind.md
    # assumes that port 31001 #deploy/kind/kind-cluster.yaml

    # https://github.com/kubernetes-sigs/kind/releases
    # curl https://github.com/kubernetes-sigs/kind/releases/download/v0.11.1/kind-linux-amd64 -o KIND

    mkdir KIND
    cd KIND
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
    chmod +x ./kind
    # mv ./kind /usr/local/bin/kind
    export PATH=$PATH:$PWD
    cd ..
}
    
set_wskcluster(){
# create a default mycluster.yaml for a single worker node
# https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy
# https://github.com/apache/openwhisk-deploy-kube/issues/226
echo 'affinity:
  enabled: false
toleration:
  enabled: false
invoker:
  options: "-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false"
' > mycluster.yaml
# -------- or ----------
# echo "whisk:
#   ingress:
#     type: NodePort
#     apiHostName: $apiHostName
#     apiHostPort: $apiHostPort
#     useInternally: false
# nginx:
#   httpsNodePort: $apiHostPort
# # disable affinity
# affinity:
#   enabled: false
# toleration:
#   enabled: false
# invoker:
#   options: \"-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false\"
#   # must use KCF as kind uses containerd as its container runtime
#   containerFactory:
#     impl: \"kubernetes\"
# " > mycluster.yaml
}

set_wsk_cli(){
    if ( ! wsk -i );then 
    # https://openwhisk.ng.bluemix.net/cli/go/download/
    mkdir wsk
    cd wsk
    # wget https://openwhisk.ng.bluemix.net/cli/go/download/linux/amd64/OpenWhisk_CLI-linux.tgz 
    wget https://openwhisk.ng.bluemix.net/cli/go/download/linux/amd64/wsk
    chmod +x ./wsk
    export PATH=$PATH:$PWD
    cd ..;
    fi
}

config_wsk_cli(){
    # External to the Kubernetes cluster, using wsk cli
    set_wsk_cli

    apiHostName=localhost
    apiHostPort=31001 ???
    WHISK_SERVER=$apiHostName:$apiHostPort
    WHISK_AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
    # To configure your wsk cli to connect to it, set the apihost property
    wsk property set --apihost $WHISK_SERVER --auth $WHISK_AUTH # --namespace guest
    wsk list -v
}

set_k8s(){
# install k8s Kubernetes version 1.19+, kubelet's hairpin-mode must not be none: Endpoints of Kubernetes services must be able to loopback to themselves
# https://www.howtoforge.com/tutorial/how-to-install-kubernetes-on-ubuntu/
# add a signing key in you on Ubuntu, adding a subscription key
apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests gnupg apt-transport-https
set_curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add # curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

if ( ! kubectl version --client ); then 
	# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
	RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
	ARCH="amd64"
	curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
	chmod +x {kubeadm,kubelet,kubectl}
	export PATH=$PATH:$PWD
        chown $(id -u):$(id -g) /etc/kubernetes/admin.conf
        export KUBECONFIG=/etc/kubernetes/admin.conf  # https://k21academy.com/docker-kubernetes/the-connection-to-the-server-localhost8080-was-refused/
        # export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        # echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> $HOME/.bashrc
        #curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && export PATH=$PATH:$PWD && cd ..
	#apt-get update && apt-get -y upgrade && apt-get install software-properties-common python-software-properties # apt-get install apt-file && apt-file update -y # apt-file search add-apt-repository
	#apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" # sed -i -e '50d' /etc/apt/sources.list # sed -i '50s/\(.*\)/#\1/' /etc/apt/sources.list
	#apt-get update && apt-get -y upgrade && apt-get install kubeadm kubelet kubectl # apt update && apt install -y kubeadm kubelet kubectl
	#apt-mark hold kubeadm kubelet kubectl;
fi
}

deploy_k8s(){
	# In order to set up the Kubernetes Linux servers, disabling the swap memory on each server
	swapon -s
	swapoff –a

	# set as the master node
	if [ ! -n "$master_node" ]; then read -p "Your master_node Name? :" master_node; fi
	hostnamectl set-hostname $master_node

	# init k8s cluster
	cidr=10.244.0.0/16
	kubeadm init --pod-network-cidr=$cidr
	# kubeadm init --pod-network-cidr=$cidr --apiserver-advertise-address=10.0.15.10 #--kubernetes-version "1.21.0"
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
helm upgrade $owdev ./helm/openwhisk -n $openwhisk -f mycluster.yaml # using helm
kind load docker-image whisk/controller # using kind
}

# (set_kind_config)
create_k8scluster(){
	# ensure that Kubernetes is cloned in $(env PATH)/src/k8s.io/kubernetes
	if [ ! -n "$cluster_name" ]; then read -p "Your K8s Cluster Name? cluster names must match `^[a-z0-9.-]+\$`:" cluster_name; fi
	# (set_kind_config)
	kind create cluster --name $cluster_name #(--config kind-example-config.yaml) # --image=... --wait 30s 
	kind get clusters
	# kind delete clusters $cluster_name
	kubectl cluster-info --context kind-$cluster_name
	kubectl get po -A  # kubectl get pods -n $openwhisk --watch
	kubectl get nodes

	if [ ! -n "$docker_image_name_1" ]; then read -p "Your docker_image Name? :" docker_image_name_1; fi
	kind load docker-image $docker_image_name_1 --name $cluster_name
	# kind load docker-image $docker_image_name_1 $docker_image_name_2 --name $cluster_name
	set_stanza

	# kubectl apply -f $my-manifest-using-my-image:$image_version
	kind export logs $PWD --name $cluster_name

	# must use the KubernetesContainerFactory when running OpenWhisk on kind
}

set_openwhisk(){
    
    set_helm3
    # Deploy OpenWhisk with Helm
    # add a chart repository
    helm repo add openwhisk https://openwhisk.apache.org/charts
    helm repo update

    
    set_kind
    set_k8s
    # (set_kind_config)
    create_k8scluster
    
    
(deploy_k8s)

    owdev=??  #deployment name # Your named release
    openwhisk=??  #namespace
    # set $OPENWHISK_HOME to its top-level directory
    export OPENWHISK_HOME=$PWD/openwhisk-deploy-kube
    
    config_wsk_cli
    set_wskcluster
    helm install $owdev $OPENWHISK_HOME/helm/openwhisk -n $openwhisk --create-namespace -f mycluster.yaml
    # helm upgrade $owdev $OPENWHISK_HOME/helm/openwhisk -n $openwhisk -f mycluster.yaml 
    # helm uninstall $owdev --namespace $openwhisk

    # Once the 'owdev-install-packages' Pod is in the `Completed` state, your OpenWhisk deployment is ready to be used.
    helm status $owdev -n $openwhisk
    

    # Once the deployment is ready, you can test it with 
    # helm test $owdev -n $openwhisk --cleanup
    cd ..
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
