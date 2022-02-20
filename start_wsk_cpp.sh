# https://raw.githubusercontent.com/delphieritas/openwhisk_scripts/main/start.sh
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

set_docker(){
# Check your Docker version
if (! docker --version ); then echo "
Be aware that you cannot install/start Docker inside a Docker container:
https://stackoverflow.com/questions/51857634/cannot-connect-to-the-docker-daemon-at-unix-var-run-docker-sock-is-the-docke
https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
\
You do not have Docker installed, please follow this website to install it first:
https://docs.docker.com/engine/installation/#installation"
set_cert
set_curl

# curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh;
apt-get install -y -qq apt-transport-https gnupg
curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends docker-ce-cli docker-scan-plugin docker-ce docker-ce-rootless-extras;
fi

# start docker
if (! systemctl --version ); then 
    apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends --no-install-suggests systemctl && systemctl start docker;
fi
}

set_k8s(){
# https://microk8s.io
# https://techexpert.tips/kubernetes/kubernetes-installation-ubuntu-linux/
if (! kubectl version | grep 'Server Version: ' ); then 
kubeadm config images pull
# export KUBECONFIG=/etc/kubernetes/admin.conf

# init k8s cluster
cidr=10.244.0.0/16
sudo kubeadm init --pod-network-cidr=$cidr --apiserver-advertise-address=10.0.15.10 #--kubernetes-version "1.21.0"

# In order to set up the Kubernetes Linux servers, disabling the swap memory on each server
swapon -s
swapoff –a
hostnamectl set-hostname kubernetes-01.local
; fi

# join any number of worker nodes by running the following on each as root:
# kubeadm join 192.168.100.9:6443 --token l7fezg.2nm80pvehn2f2bbz \
#     --discovery-token-ca-cert-hash sha256:6dfc8c80e8e125c6d4d79ec82ea64deb0dcfa0a4bda33e16a8a9fa93794e3aae

# tech requirements:
# https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/k8s-technical-requirements.md
# Unless you disable persistence (see configurationChoices.md), either your cluster must be configured to support Dynamic Volume Provision and you must have a DefaultStorageClass admission controller enabled or you must manually create any necessary PersistentVolumes when deploying the Helm chart.
# Endpoints of Kubernetes services must be able to loopback to themselves (the kubelet's hairpin-mode must not be none).
}

set_helm3(){
# v3.2.0++
if ( ! helm version ); then 
    set_cert
    set_curl 

    # mkdir helm3
    # cd helm3
    curl -LO https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz
    tar -zxvf helm-v3.7.0-linux-amd64.tar.gz
    chmod +x ./helm
    export PATH=$PATH:$PWD
    rm helm-v3.7.0-linux-amd64.tar.gz
    # cd ..
; fi
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
# - role: worker
" > k8s.yaml # https://github.com/apache/openwhisk-deploy-kube/issues/311 https://github.com/apache/openwhisk-deploy-kube/issues/303
}

set_kind(){
if ( ! kind version ); then 
    #mkdir KIND
    #cd KIND
    set_cert
    set_curl 
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
    chmod +x ./kind
    # mv ./kind /usr/local/bin/kind
    export PATH=$PATH:$PWD
    #cd ..
; fi
}

set_wsk_yaml(){
# create a default wsk.yaml for a single worker node
### TODO: 'apiHostPort: ' doesn't matter?
echo "whisk:
  ingress:
    type: NodePort
    apiHostName: $apiHostName
    apiHostPort: $apiHostPort 
#    useInternally: false
nginx:
  httpsNodePort: $apiHostPort" > wsk.yaml 

# If your cluster has a single worker node, then you should configure OpenWhisk without node affinity. 
# This is done by adding the following lines to your wsk.yaml 
echo '# disable affinity
affinity:
 enabled: false
toleration:
 enabled: false
invoker:
 options: \"-Dwhisk.kubernetes.user-pod-node-affinity.enabled=false\"
 # must use KCF as kind uses containerd as its container runtime
 containerFactory:
   impl: \"kubernetes\" ' >> wsk.yaml
# Decoupling the database
echo 'db:
  wipeAndInit: false' >> wsk.yaml
}

set_wsk_cli(){
    if ( ! wsk -i ); then 
    set_wget
    # https://openwhisk.ng.bluemix.net/cli/go/download/
    # mkdir wsk
    # cd wsk
    # wget https://openwhisk.ng.bluemix.net/cli/go/download/linux/amd64/OpenWhisk_CLI-linux.tgz 
    wget https://openwhisk.ng.bluemix.net/cli/go/download/linux/amd64/wsk
    chmod +x ./wsk
    export PATH=$PATH:$PWD
    # cd ..;
; fi
}

config_wsk_cli(){
    # External to the Kubernetes cluster, using wsk cli
    # set_wsk_cli

    # https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/README.md
    # WHISK_SERVER=$apiHostName:31001   # $apiHostPort
    # To configure your wsk cli to connect to it, set the apihost property
    # wsk property set --apihost $WHISK_SERVER  #--auth $WHISK_AUTH 
    wsk -i property get #> namespace == guest ### TODO: connection reset by peer
            # whisk API host          localhost:31001
            # whisk auth              23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP   # WHISK_AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
            # whisk namespace         guest
            # client cert
            # Client key
            # whisk API version       v1
            # whisk CLI version       2021-04-01T23:49:54.523+0000
            # whisk API build         2020-10-20-01:00:00Z
            # whisk API build number  v1.0.0:20201020a
}

set_k8s_cli(){
# install k8s Kubernetes version 1.19+, kubelet's hairpin-mode must not be none: Endpoints of Kubernetes services must be able to loopback to themselves
# https://www.howtoforge.com/tutorial/how-to-install-kubernetes-on-ubuntu/
# add a signing key in you on Ubuntu, adding a subscription key
    if (! apt-cache search "gnupg" |grep "gnupg"); then
        apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests gnupg apt-transport-https
    ;fi

    set_curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add # curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

if ( ! kubectl version --client ); then 
    # https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
    # https://tipsfordev.com/kubectl-get-the-connection-to-the-server-localhost-8080-was-refused-kubernetes
    RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    ARCH="amd64"
    curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}
    export PATH=$PATH:$PWD
        chown $(id -u):$(id -g) /etc/kubernetes/ #admin.conf -R  # chmod 644 /etc/kubernetes/admin.conf
        export KUBECONFIG=/etc/kubernetes/admin.conf  # https://k21academy.com/docker-kubernetes/the-connection-to-the-server-localhost8080-was-refused/
    # cp -i /etc/kubernetes/admin.conf $HOME/admin.conf
    # chown $(id -u):$(id -g) $HOME/admin.conf # chown 1033:2000 /dir
    # export KUBECONFIG=$HOME/admin.conf

        # echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> $HOME/.bashrc
        #curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x kubectl && export PATH=$PATH:$PWD && cd ..
    #apt-get update && apt-get -y upgrade && apt-get install software-properties-common python-software-properties # apt-get install apt-file && apt-file update -y # apt-file search add-apt-repository
    #apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" # sed -i -e '50d' /etc/apt/sources.list # sed -i '50s/\(.*\)/#\1/' /etc/apt/sources.list
    #apt-get update && apt-get -y upgrade && apt-get install kubeadm kubelet kubectl # apt update && apt install -y kubeadm kubelet kubectl
    #apt-mark hold kubeadm kubelet kubectl;
; fi
}

create_k8scluster(){
    # ensure that Kubernetes is cloned in $(env PATH)/src/k8s.io/kubernetes
    if [ ! -n "$cluster_name" ]; then read -p "Your K8s Cluster Name? cluster names must match `^[a-z0-9.-]+\$`, e.g. cpp-cluster:" cluster_name; fi
    # set_k8s_yaml
    
    # delete existing openwhisk runtime and k8s cluster
    helm uninstall $owdev -n $openwhisk
    kind delete clusters $cluster_name 
    # kubectl config get-clusters
    kubectl config delete-cluster $cluster_name ### TODO: try to delete all clusters
    # kubeadm config images pull
    export KUBECONFIG=$PWD/admin.conf   # $HOME/admin.conf # /etc/kubernetes/admin.conf 
    kind create cluster --name $cluster_name --config $PWD/k8s.yaml # --image=... --wait 30s --wait 10m 

# kubectl config set-cluster $cluster_name --server=127.0.0.1:46878
    kubectl get services #-n kube-system    ## owdev-, owdev-couchdb, owdev-controller, owdev-apigateway
    kubectl cluster-info --context kind-$cluster_name # Kubernetes control plane is running at https://127.0.0.1:40161 # CoreDNS is running at https://127.0.0.1:40161/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
    kubectl get nodes # kind get clusters   ## cluster0-control-plane, cluster0-worker

    
    docker ps -a
    # docker logs -f <container_id>
    # kubectl logs owdev-init-couchdb-rcqp2 -n $openwhisk
    # kubectl describe pod owdev-init-couchdb-2zhwh --namespace=$openwhisk

    # kubectl apply -f $my-manifest-using-my-image:$image_version
    # kind export logs $PWD/k8s_logs --name $cluster_name
}

deploy_wsk_cluster(){
    # add a chart repository
    # helm repo add openwhisk https://openwhisk.apache.org/charts # helm repo add stable https://charts.helm.sh/stable
    # helm repo update
    # set_wsk_yaml
    helm install $owdev $openwhisk/openwhisk -n $openwhisk --create-namespace -f wsk.yaml # helm ls # helm status $owdev -n $openwhisk

    # helm upgrade $owdev $OPENWHISK_HOME/helm/openwhisk -n $openwhisk -f wsk.yaml 
}

set_tools(){
    set_helm3
    set_wsk_cli
    
    set_kind
    set_k8s_cli
    # (set_k8s)
}

set_openwhisk(){
    set_tools

    # docker ps -a ## 0.0.0.0:31001->31001/tcp    cluster0-worker
    apiHostName=localhost
    apiHostPort=31001
    
    # set_k8s_yaml
    create_k8scluster

    # owdev=test_cpp  #deployment name # Your named release
    # openwhisk=openwhisk  #namespace

    # Deploy OpenWhisk with Helm
    deploy_wsk_cluster

    # Once the 'owdev-install-packages' Pod is in the `Completed` state, your OpenWhisk deployment is ready to be used.
    kubectl get pods -o wide -A # kubectl get po -A  # kubectl get pods -n $openwhisk --watch    
    
    # wsk CLI namespace `guest` !

    # kubectl logs <$pod_name> -n $openwhisk
    # kubectl describe pod <$pod_name>  --namespace=$openwhisk
        ## https://github.com/apache/incubator-openwhisk-deploy-kube/tree/master/docker/couchdb

    
    docker ps
    kubectl describe node  | grep InternalIP: | awk '{print $2}'
    # kubectl describe node $cluster_name-worker  | grep InternalIP: | awk '{print $2}'
    config_wsk_cli

    # kubectl label nodes --all openwhisk-role=invoker # for single node in the cluster https://apache.googlesource.com/openwhisk-deploy-kube/+/4a9637d938f479b9e1036f991d7d54b1bf74683c/README.md#initial-setup https://github.com/apache/openwhisk-deploy-kube/blob/master/README.md#initial-setup

    ## Once the deployment is ready, you can test it with 
    # helm test $owdev -n $openwhisk --cleanup
    # cd ..
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

set_cmakefile(){
echo '
# https://blog.csdn.net/u012483097/article/details/108797976
cmake_minimum_required(VERSION 3.13)
project(example)

set(CMAKE_CXX_STANDARD 14)

# https://blog.devgenius.io/calling-python-and-c-code-using-pybind-99ab7fefa685
include(FetchContent)
FetchContent_Declare(
    pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11.git
    GIT_TAG        v2.6.2
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(pybind11)

pybind11_add_module(example example.cpp)
target_compile_features(example PUBLIC cxx_std_14)
set_target_properties(example PROPERTIES SUFFIX ".so")
'>CMakeLists.txt
}

set_cppfile(){
echo '
// https://blog.devgenius.io/calling-python-and-c-code-using-pybind-99ab7fefa685
#include <pybind11/embed.h>
int multiply(int i, int j) {
    return i * j;
}

PYBIND11_MODULE(example, m) {
    m.doc() = "pybind11 example plugin"; // optional module docstring
    m.def("multiply", &multiply, "A function which multiplies two numbers");
}'>example.cpp
}

set_dockerfile(){
echo "FROM debian:buster AS base

RUN set -ex;         \
    apt-get update;  \
    apt-get install -y libzmq5

FROM base AS builder

RUN set -ex;   \
    apt-get update && apt-get -y upgrade && \
    apt-get install -y g++ curl  libzmq3-dev libblkid-dev e2fslibs-dev libboost-all-dev libaudit-dev python-pybind11;   \
    mkdir -p /usr/src

COPY . /usr/src/example

RUN set -ex;              \
    #python -m pip install pybind11;   \
    apt-get install -y python-pybind11; \
apt-get install -y cmake git; git clone https://gitlab.kitware.com/cmake/cmake.git; cd cmake; git checkout tags/v3.14.7; mkdir build; cd build; cmake ..; cmake --build .; cpack -G DEB; apt remove -y cmake-data; dpkg -i cmake-3.14.7-Linux-x86_64.deb; \
    cd /usr/src/example/example_func;  \
    cmake -D python_version=3.5 . ; make

FROM openwhisk/python3aiaction:latest AS runtime
# FROM ibmfunctions/action-python-v3 AS runtime

COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/bin/cmake /usr/bin/cmake
COPY --from=builder /usr/src/example/example_func /usr/local/bin

RUN export PATH=\$PATH:/usr/local/bin; \
    chown -R 1033:2000 /actionProxy/actionproxy.py /usr/local/bin; \
    cd /usr/lib/python3.5/; ln -s /usr/local/bin/example.so
ENV PYTHONPATH /usr/lib/python3.5:/usr/lib/python2.7/dist-packages:/usr/lib/python3.5/dist-packages:/usr/local/bin

" > $dockerfile.Dockerfile

# echo "FROM openwhisk/python3aiaction:latest

# RUN pip freeze | grep tensor| xargs pip uninstall -y
# RUN pip freeze | grep torch| xargs pip uninstall -y
# RUN pip freeze | grep sci| xargs pip uninstall -y
# RUN pip freeze | grep jupyter| xargs pip uninstall -y
# RUN pip freeze | grep notebook| xargs pip uninstall -y
# RUN pip freeze | grep matplotlib | xargs pip uninstall -y
# RUN pip freeze | grep Keras | xargs pip uninstall -y

# RUN rm -rf /usr/local/bin/pip3 /usr/local/bin/pip /usr/local/bin/pip3.5 /usr/local/bin/ipython3 /usr/local/bin/ipython /usr/local/bin/jupyter /usr/local/bin/jupyter-bundlerextension /usr/local/bin/jupyter-console /usr/local/bin/jupyter-kernel /usr/local/bin/jupyter-kernelspec /usr/local/bin/jupyter-migrate /usr/local/bin/jupyter-nbconvert /usr/local/bin/jupyter-nbextension /usr/local/bin/jupyter-notebook /usr/local/bin/jupyter-qtconsole /usr/local/bin/jupyter-run /usr/local/bin/jupyter-serverextension /usr/local/bin/jupyter-troubleshoot /usr/local/bin/jupyter-trust

# RUN apt-get update && apt-get install -y liblzma-dev libbz2-dev wget \
# # && apt install  \ #  bzip2* lzma \ # && apt  apt install -y wget \
# && wget https://www.python.org/ftp/python/3.9.7/Python-3.9.7.tgz \
# && tar xzf Python-3.9.7.tgz \ 
# && cd Python-3.9.7 \ 
# && ./configure --enable-optimizations \ 
# && make altinstall 

# RUN echo 'alias python=python3.9' >> ~/.bashrc && echo 'alias pip=pip3.9' >> ~/.bashrc && alias python=python3.9 && alias pip=pip3.9

# RUN pip3.9 install torch==1.10.0+cu113 torchvision==0.11.1+cu113 -f https://download.pytorch.org/whl/cu113/torch_stable.html

# #COPY *.py ./
# #RUN chmod +x *" > $dockerfile.Dockerfile
}

create_docker_image(){
        set_docker
    set_dockerfile
    set_cmakefile
    set_cppfile

    docker build -t $docker_image -f $dockerfile.Dockerfile $PWD
    # # docker run -v $PWD:/notebooks -it $docker_image bash
    docker image tag $docker_image $docker_user/$docker_image
    docker push $docker_user/$docker_image:latest
    # docker pull $docker_user/$docker_image:latest
}

create_invoke_wsk_action(){
# the CLI flag --web true this command will add both annotations web-export=true and final=true. https://github.com/apache/openwhisk/blob/59b67fe96f44e573f3348afed966a1cdaf80ddf2/docs/rest_api.md
    
    wsk -i action create $action_name --docker $docker_user/$docker_image:latest # wsk -i action create $action_name --docker $docker_user/$docker_image:latest $pythonfile -d --web true --timeout 80000
    # wsk -i action update $action_name $pythonfile --timeout 80000
    # wsk -i action update $action_name action.zip --main action_handler  \
    #     --param model_url "$1" \
    #     --param from_upper Eyes \
    #     --param to_lower Hips \
    #     --memory 3891 \
    #     --docker adobeapiplatform/openwhisk-python3aiaction:0.11.0

    # wsk -i action invoke $action_name -b --param name "alex" --debug  # InitTime, response.result, response.status, 
    # https://stackoverflow.com/questions/556405/what-do-real-user-and-sys-mean-in-the-output-of-time1/556411#556411
    wsk -i list # wsk -i list -v
    time wsk -i action invoke $action_name -b --param name "alex"  # real 0m34,832s  user 0m0,113s  sys 0m0,080s  ## --param image "https://i.pinimg.com/236x/17/1c/a6/171ca6b06111529aa6f10b1f4e418339--style-men-my-style.jpg"  --param from_upper Eyes --param to_lower Elbows
    # https://github.com/apache/openwhisk/blob/master/docs/actions.md

    action_id=`wsk -i activation list |grep $action_name | awk '{print $3}'`
    action_id=`echo $action_id | awk '{print $1}'` && echo $action_id
    # To get function return outs
    wsk -i activation result $action_id # time wsk -i action invoke $action_name -b --param name "alex" --result
    # To get function print outs
    wsk -i activation logs $action_id
    # To get action detailed logs
    wsk -i activation get $action_id  # wsk -i activation get --last
    # wsk -i action delete $action_name
}

wsk_cli_create_invoke(){
    set_pyfile
    
    if [ ! -n "$pythonfile" ]; then read -p "Your python file name? e.g. hello.py:" pythonfile; fi
    if [ ! -n "$docker_user" ]; then read -p "Your Docker user name? :" docker_user; fi
    if [ ! -n "$docker_image" ]; then read -p "Your Docker Image name? :" docker_image; fi
    if [ ! -n "$action_name" ]; then read -p "Your Openwhisk Action name? e.g. func_1:" action_name; fi
    if [ ! -n "$dockerfile" ]; then read -p "Your Dockerfile name? e.g. vgg.Dockerfile:" dockerfile; fi

    create_docker_image
    
    create_invoke_wsk_action
}

wsk_cli_create_trigger(){
    # https://openwhisk.apache.org/documentation.html
    wsk trigger create -i $trigger_name
    # Firing a trigger like this currently does not do anything. We need to associate this trigger with an action. This kind of association is called a rule.
    # You can create multiple rules that associate the same trigger with different actions. 
    wsk rule create -i $rule_name $trigger_name $action_name
    wsk trigger fire -i $trigger_name
    # activation_id=`wsk activation list --limit 1 -i | awk '{print $3}'` && echo $action_id
    # wsk activation result -i $activation_id
}

debug(){
# Debug K8s cluster nodes 
kubectl get pods -o wide -A

# Debug containers
worker_container_id=`docker ps -a|grep $cluster_name-worker | awk '{print $1}'` && echo $worker_container_id
docker logs -f $worker_container_id

# Debug K8s cluster nodes / pod
pod_name=`kubectl get pods -o wide -A |grep $cluster_name-worker |grep Error |awk '{print $2}'` && echo $pod_name
# kubectl describe pod [pod-name] # kubectl describe  [pod-name]
# kubectl exec [pod-name] -it sh
kubectl logs $pod_name -n $openwhisk
# kubectl describe pod $pod_name --namespace=$openwhisk
# kubectl apply -f $my-manifest-using-my-image:$image_version

# Debug actions
wsk -i activation get $action_id  # wsk -i activation get --last
}

rest_api(){
wsk -i list
wsk -i list -v
wsk -i namespace list -v
if [ ! -n "$apiHostName" ]; then read -p "Your api host name? e.g. localhost" apiHostName; fi # apiHostName=localhost
if [ ! -n "$apiHostPort" ]; then read -p "Your api host port? e.g. 31001:" apiHostPort; fi # apiHostPort=31001
if [ ! -n "$openwhisk" ]; then read -p "Your namespace? e.g. openwhisk:" openwhisk; fi # openwhisk=openwhisk  # default / _
if [ ! -n "$action_name" ]; then read -p "Your Openwhisk Action name? e.g. func_1:" action_name; fi
if [ ! -n "$inputs" ]; then read -p "Your inputs? e.g. '{\"name\":\"John\"}':" inputs; fi # inputs='{"name":"John"}'
APIHOST=$apiHostName:$apiHostPort 
namespace=_
# https://github.com/apache/openwhisk/blob/master/docs/rest_api.md
curl -insecure "https://$APIHOST/api/v1/namespaces/${namespace}/actions/${action_name}?blocking=true&result=true" -X POST -H "Content-Type: application/json" -d ${inputs}

# https://github.com/apache/openwhisk/blob/master/docs/webactions.md
# curl -insecure https://${APIHOST}/api/v1/web/${namespace}/default/${action_name}.json?name=Jane
# curl -insecure https://${APIHOST}/api/v1/web/${namespace}/default/${action_name}.json -H 'Content-Type: text/plain' -d "Jane"
AUTH=`wsk -i property get --auth |  awk '{print $3}'`
# curl -u $AUTH
}

clean_up(){
    wsk -i action delete $action_name
    helm uninstall $owdev -n $openwhisk #--keep-history
    kind delete clusters $cluster_name
}

print_usage() {
  printf "Usage: bash start_with_flags.sh -flag1 <val1> -flag2 <val2> ....
  e.g. :
  bash start_with_flags.sh -c 280277xxxxxx -r us-east-1 -a AKIAIOSFODNN7EXAMPLE -s wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY -t csgmcmc_random_lambda_trigger -w csgmcmc_random_lambda -p sudoPolicy -d cifar10 -e 100 -n 1
"
}

start(){
if [ ! -n "$1" ] ;then
    print_usage
exit 1;
fi
    owdev=test-cpp  #deployment name # Your named release
    openwhisk=openwhisk  #namespace
    export PATH=$PATH:/hdd1/yangnan/lemonviv/
    # cd /hdd1/yangnan/lemonviv/openwhisk-deploy-kube
    # cd /hdd1/yangnan/Singa/test_cpp

while getopts 'c:f:i:u:a:p:' flag; do
  case "${flag}" in
    c) cluster_name="${OPTARG}" ;; # cpp-cluster
    f) dockerfile="${OPTARG}" ;;
    i) docker_image="${OPTARG}" ;;
    u) docker_user="${OPTARG}" ;;
    a) action_name="${OPTARG}" ;;
    p) pythonfile="${OPTARG}" ;;
    *) print_usage;;
  esac
done

set_openwhisk
wsk_cli_create_invoke
wsk_cli_create_trigger
# debug
rest_api
# clean_up
}
