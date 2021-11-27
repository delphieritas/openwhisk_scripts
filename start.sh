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

set_k8s_yaml(){
    # for multi-node cluster
    # https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy/kind/kind-cluster.yaml
    echo "kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
    - hostPort: $apiHostPort
      containerPort: 31001
- role: worker" > k8s.yaml # https://github.com/apache/openwhisk-deploy-kube/issues/311 https://github.com/apache/openwhisk-deploy-kube/issues/303
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

# ???
set_wsk_yaml(){
# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-kind.md # https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy
# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-diy.md
# https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/k8s-kind.md#configuring-openwhisk https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/configurationChoices.md
# https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy/kind/mycluster.yaml # https://github.com/apache/openwhisk-deploy-kube/tree/master/deploy
# mac https://github.com/apache/openwhisk-deploy-kube/blob/master/deploy/docker-macOS/mycluster.yaml
echo "whisk:
  ingress:
    type: NodePort
    apiHostName: $apiHostName
    apiHostPort: $apiHostPort
#    useInternally: false
nginx:
  httpsNodePort: $apiHostPort" > mycluster.yaml 

# create a default mycluster.yaml for a single worker node
# If your cluster has a single worker node, then you should configure OpenWhisk without node affinity. This is done by adding the following lines to your mycluster.yaml https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#initial-setup https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/README.md
echo '# disable affinity
affinity:
 enabled: false
toleration:
 enabled: false
invoker:
 options: \"-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false\"
 # must use KCF as kind uses containerd as its container runtime
 containerFactory:
   impl: \"kubernetes\" ' >> mycluster.yaml
# -------- or ---------
# echo '
# invoker:
#  # must use KCF as kind uses containerd as its container runtime
#  containerFactory:
#    impl: \"kubernetes\" 
# ' >> mycluster.yaml
# https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/k8s-kind.md#configuring-openwhisk https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/configurationChoices.md
# https://github.com/apache/openwhisk-deploy-kube/issues/311 https://github.com/apache/openwhisk-deploy-kube/issues/226
# --------------------
# Decoupling the database
# https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/configurationChoices.md
# echo 'db:
#   wipeAndInit: false' >> mycluster.yaml
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

# 	https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/README.md
    WHISK_SERVER=$apiHostName:$apiHostPort
    WHISK_AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
    # To configure your wsk cli to connect to it, set the apihost property
    wsk property set --apihost $WHISK_SERVER   # --auth $WHISK_AUTH
    wsk list -v
    wsk property -i get
}

set_k8s_cli(){
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
        chown $(id -u):$(id -g) /etc/kubernetes/ #admin.conf
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

# ???
deploy_k8s(){
	# In order to set up the Kubernetes Linux servers, disabling the swap memory on each server
	swapon -s
	swapoff –a

	# set as the master node
	if [ ! -n "$master_node" ]; then read -p "Your master_node Name? :" master_node; fi
	hostnamectl set-hostname $master_node

	# init k8s cluster
	cidr=10.244.0.0/16
	sudo kubeadm init --pod-network-cidr=$cidr
	# kubeadm init --pod-network-cidr=$cidr --apiserver-advertise-address=10.0.15.10 #--kubernetes-version "1.21.0"
	
	# tech requirements:
	# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-technical-requirements.md
	# Unless you disable persistence (see configurationChoices.md), either your cluster must be configured to support Dynamic Volume Provision and you must have a DefaultStorageClass admission controller enabled or you must manually create any necessary PersistentVolumes when deploying the Helm chart.
	# Endpoints of Kubernetes services must be able to loopback to themselves (the kubelet's hairpin-mode must not be none).
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

# (set_k8s_yaml)
create_k8scluster(){
	# ensure that Kubernetes is cloned in $(env PATH)/src/k8s.io/kubernetes
	if [ ! -n "$cluster_name" ]; then read -p "Your K8s Cluster Name? cluster names must match `^[a-z0-9.-]+\$`:" cluster_name; fi
	set_k8s_yaml
	kind create cluster --name $cluster_name --config $PWD/k8s.yaml # --image=... --wait 30s --wait 10m 
	
	# kind delete clusters $cluster_name
	kubectl cluster-info --context kind-$cluster_name
	kubectl get nodes # kind get clusters
	kubectl get services #-n kube-system
	
	docker ps -a
	# docker logs -f <container_id>
	kubectl describe node  | grep InternalIP: | awk '{print $2}' # https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/docs/k8s-kind.md
	# kubectl logs owdev-init-couchdb-rcqp2 -n $openwhisk
	# kubectl describe pod owdev-init-couchdb-2zhwh --namespace=$openwhisk


			# ???
			if [ ! -n "$docker_image_name_1" ]; then read -p "Your docker_image Name? :" docker_image_name_1; fi
			kind load docker-image $docker_image_name_1 --name $cluster_name
			# kind load docker-image $docker_image_name_1 $docker_image_name_2 --name $cluster_name
			set_stanza

	# kubectl apply -f $my-manifest-using-my-image:$image_version
	# kind export logs $PWD/k8s_logs --name $cluster_name

	# must use the KubernetesContainerFactory when running OpenWhisk on kind
}

set_openwhisk(){
    
    set_helm3
    # Deploy OpenWhisk with Helm
    # add a chart repository
    helm repo add openwhisk https://openwhisk.apache.org/charts # helm repo add stable https://charts.helm.sh/stable
    helm repo update

    
    set_kind
    set_k8s_cli
    

    apiHostName=localhost
    apiHostPort=31001 ???
    
    # set_k8s_yaml
    create_k8scluster

	# (deploy_k8s) # ???

    owdev=owdev ???  #deployment name # Your named release
    openwhisk=openwhisk ???  #namespace
    # set $OPENWHISK_HOME to its top-level directory
    export OPENWHISK_HOME=$PWD/openwhisk-deploy-kube

    set_wsk_yaml
    helm install $owdev $OPENWHISK_HOME/helm_repo/openwhisk -n $openwhisk --create-namespace -f mycluster.yaml # helm ls # helm status $owdev -n $openwhisk
    # helm upgrade $owdev $OPENWHISK_HOME/helm/openwhisk -n $openwhisk -f mycluster.yaml 
    # helm uninstall $owdev --namespace $openwhisk

    # Once the 'owdev-install-packages' Pod is in the `Completed` state, your OpenWhisk deployment is ready to be used.
    kubectl get pods -o wide -A # kubectl get po -A  # kubectl get pods -n $openwhisk --watch    

    # kubectl logs <$pod_name> -n $openwhisk
    # kubectl describe pod <$pod_name>  --namespace=$openwhisk
    	## https://github.com/apache/incubator-openwhisk-deploy-kube/tree/master/docker/couchdb
	#git config --global --unset http.proxy
	#git config --global --unset https.proxy
	## blog.csdn.net/weixin_42018581/article/details/103079725
	## https://blog.csdn.net/qq_38415505/article/details/83687207
	## blog.csdn.net/Dashi_Lu/article/details/89641778
    
    # docker ps
    kubectl describe node $cluster_name-worker  | grep InternalIP: | awk '{print $2}'
    config_wsk_cli

    # kubectl label nodes --all openwhisk-role=invoker # for single node in the cluster https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/README.md#initial-setup https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#initial-setup

    ## Once the deployment is ready, you can test it with 
    # helm test $owdev -n $openwhisk --cleanup
    cd ..
}

set_pyfile(){
echo '
def main(args):
    name = args.get("name", "stranger")
    greeting = "Hello " + name + "!"
    print({"greeting": greeting})
    return {"greeting": greeting}
if __name__ == "__main__":
	main({ 
    	"name": "alex"})
	print(main)' > hello.py
}

# ???
set_manifest(){
echo '		packages:
		    default:
		        actions:
		            helloPy:
		                function: hello.py
                		runtime: python:3' > manifest.yaml
}

set_dockerfile(){
echo "FROM openwhisk/python3aiaction:latest

RUN pip freeze | grep tensor| xargs pip uninstall -y
RUN pip freeze | grep torch| xargs pip uninstall -y
RUN pip freeze | grep sci| xargs pip uninstall -y
RUN pip freeze | grep jupyter| xargs pip uninstall -y
RUN pip freeze | grep notebook| xargs pip uninstall -y
RUN pip freeze | grep matplotlib | xargs pip uninstall -y
RUN pip freeze | grep Keras | xargs pip uninstall -y

RUN rm -rf /usr/local/bin/pip3 /usr/local/bin/pip /usr/local/bin/pip3.5 /usr/local/bin/ipython3 /usr/local/bin/ipython /usr/local/bin/jupyter /usr/local/bin/jupyter-bundlerextension /usr/local/bin/jupyter-console /usr/local/bin/jupyter-kernel /usr/local/bin/jupyter-kernelspec /usr/local/bin/jupyter-migrate /usr/local/bin/jupyter-nbconvert /usr/local/bin/jupyter-nbextension /usr/local/bin/jupyter-notebook /usr/local/bin/jupyter-qtconsole /usr/local/bin/jupyter-run /usr/local/bin/jupyter-serverextension /usr/local/bin/jupyter-troubleshoot /usr/local/bin/jupyter-trust

RUN apt-get update && apt-get install -y liblzma-dev libbz2-dev wget \
# && apt install  \ #  bzip2* lzma \ # && apt  apt install -y wget \
&& wget https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz \
&& tar xzf Python-3.9.7.tgz \ 
&& cd Python-3.9.7 \ 
&& ./configure --enable-optimizations \ 
&& make altinstall 

RUN echo 'alias python=python3.9' >> ~/.bashrc && echo 'alias pip=pip3.9' >> ~/.bashrc && alias python=python3.9 && alias pip=pip3.9

RUN pip3.9 install torch==1.10.0+cu113 torchvision==0.11.1+cu113 -f https://download.pytorch.org/whl/cu113/torch_stable.html

COPY hello.py .
RUN chmod +x *" > $dockerfile.Dockerfile
#----------------
# echo"FROM openwhisk/python3aiaction:latest

# RUN pip freeze | grep tensor| xargs pip uninstall -y
# # RUN pip freeze | grep torch| xargs pip uninstall -y
# RUN pip freeze | grep sci| xargs pip uninstall -y
# RUN pip freeze | grep jupyter| xargs pip uninstall -y
# RUN pip freeze | grep notebook| xargs pip uninstall -y
# RUN pip freeze | grep matplotlib | xargs pip uninstall -y
# RUN pip freeze | grep Keras | xargs pip uninstall -y

# RUN apt update && apt install -y \
# wget && wget https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz && tar xzf Python-3.9.7.tgz  && cd Python-3.9.7  && ./configure --enable-optimizations  && make altinstall 

# COPY $pythonfile.py .
# RUN chmod +x *

# # RUN pip3.9 install torch==1.10.0+cu113 torchvision==0.11.1+cu113 -f https://download.pytorch.org/whl/cu113/torch_stable.html
# # RUN rm -rf /usr/local/bin/pip3 /usr/local/bin/pip /usr/local/bin/pip3.5 /usr/local/bin/ipython3 /usr/local/bin/ipython /usr/local/bin/jupyter /usr/local/bin/jupyter-bundlerextension /usr/local/bin/jupyter-console /usr/local/bin/jupyter-kernel /usr/local/bin/jupyter-kernelspec /usr/local/bin/jupyter-migrate /usr/local/bin/jupyter-nbconvert /usr/local/bin/jupyter-nbextension /usr/local/bin/jupyter-notebook /usr/local/bin/jupyter-qtconsole /usr/local/bin/jupyter-run /usr/local/bin/jupyter-serverextension /usr/local/bin/jupyter-troubleshoot /usr/local/bin/jupyter-trust
# # RUN echo 'alias python=python3.9' >> ~/.bashrc && echo 'alias pip=pip3.9' >> ~/.bashrc && alias python=python3.9 && alias pip=pip3.9

# EXPOSE 31000" > $dockerfile.Dockerfile
}

create_docker_image(){
	set_dockerfile

	docker build -t $docker_image -f $dockerfile.Dockerfile $PWD
	# # docker run -it  $docker_image bash
	docker image tag $docker_image $docker_user/$docker_image
	docker push $docker_user/$docker_image:latest
	# docker pull $docker_user/$docker_image:latest
}

#(set_pyfile)
wsk_cli_create_invoke(){
	set_pyfile
	
	pythonfile=hello.py ???
	docker_user= ???
	docker_image= ???
	function_name=func_1 ???
	dockerfile=vgg.Dockerfile ???

        create_docker_image
	
	wsk -i action create $function_name --docker $docker_user/$docker_image:latest $pythonfile -d --web true --timeout 80000 # wsk action create $function_name $pythonfile
	# wsk -i action update $function_name $pythonfile --timeout 100000
	# wsk -i action update $function_name action.zip --main action_handler  \
	#     --param model_url "$1" \
	#     --param from_upper Eyes \
	#     --param to_lower Hips \
	#     --memory 3891 \
	#     --docker adobeapiplatform/openwhisk-python3aiaction:0.11.0

	wsk -i action invoke $function_name -b --param name "alex" --debug \
	--result
	# !wsk action invoke smart_body_crop --param image "https://i.pinimg.com/236x/17/1c/a6/171ca6b06111529aa6f10b1f4e418339--style-men-my-style.jpg" \
	#   --param from_upper Eyes --param to_lower Elbows

	# https://github.com/apache/openwhisk/blob/master/docs/actions.md

	action_id=`wsk activation list -i |grep $function_name | awk '{print $3}'`
	wsk activation get -i $action_id # wsk activation result -i <ID> # wsk activation logs -i <ID> # wsk activation get -i --last
	# wsk -i action delete $function_name
}

# ???
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
