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
if (! docker --version ); then
set_cert
set_curl

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

# join any number of worker nodes by running the following on each as root:
# kubeadm join 192.168.100.9:6443 --token l7fezg.2nm80pvehn2f2bbz \
#     --discovery-token-ca-cert-hash sha256:6dfc8c80e8e125c6d4d79ec82ea64deb0dcfa0a4bda33e16a8a9fa93794e3aae
}

set_helm3(){
# v3.2.0++
if ( ! helm version ); then 
    set_cert
    set_curl 

    curl -LO https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz
    tar -zxvf helm-v3.7.0-linux-amd64.tar.gz
    chmod +x ./helm
    export PATH=$PATH:$PWD
    rm helm-v3.7.0-linux-amd64.tar.gz
; fi
}

set_k8s_yaml(){
# for multi-node cluster
echo "kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
  extraPortMappings:
    - hostPort: $apiHostPort
      containerPort: 31001
# - role: worker
" > k8s.yaml
}

set_kind(){
if ( ! kind version ); then 
    set_cert
    set_curl 
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
    chmod +x ./kind
    export PATH=$PATH:$PWD
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
    wget https://openwhisk.ng.bluemix.net/cli/go/download/linux/amd64/wsk
    chmod +x ./wsk
    export PATH=$PATH:$PWD
; fi
}

config_wsk_cli(){
    # External to the Kubernetes cluster, using wsk cli
    # WHISK_SERVER=$apiHostName:31001   # $apiHostPort
    # To configure your wsk cli to connect to it, set the apihost property
    # wsk property set --apihost $WHISK_SERVER
    wsk -i property get
}

set_k8s_cli(){
    # add a signing key in you on Ubuntu, adding a subscription key
    if (! apt-cache search "gnupg" |grep "gnupg"); then
        apt-get update && apt-get -y upgrade && apt-get install -y -qq --no-install-recommends --no-install-suggests gnupg apt-transport-https
    ;fi

    set_curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add 

if ( ! kubectl version --client ); then 
    RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    ARCH="amd64"
    curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
    chmod +x {kubeadm,kubelet,kubectl}
    export PATH=$PATH:$PWD
; fi
}

create_k8scluster(){
    # ensure that Kubernetes is cloned in $(env PATH)/src/k8s.io/kubernetes
    if [ ! -n "$cluster_name" ]; then read -p "Your K8s Cluster Name? cluster names must match `^[a-z0-9.-]+\$`, e.g. cpp-cluster:" cluster_name; fi
    set_k8s_yaml
    
    # delete existing openwhisk runtime and k8s cluster
    helm uninstall $owdev -n $openwhisk
    kind delete clusters $cluster_name 
    # kubectl config get-clusters
    kubectl config delete-cluster $cluster_name ### TODO: try to delete all clusters

    cp -i /etc/kubernetes/admin.conf $HOME/admin.conf
    chown $(id -u):$(id -g) $HOME/admin.conf 
    export KUBECONFIG=$HOME/admin.conf
    kind create cluster --name $cluster_name --config $PWD/k8s.yaml 

    kubectl get services 
    kubectl cluster-info --context kind-$cluster_name
    kubectl get nodes # kind get clusters

    docker ps -a
    # docker logs -f <container_id>
    # kubectl logs owdev-init-couchdb-rcqp2 -n $openwhisk
    # kubectl describe pod owdev-init-couchdb-2zhwh --namespace=$openwhisk
}

deploy_wsk_cluster(){
    # add a chart repository
    helm repo add openwhisk https://openwhisk.apache.org/charts
    helm repo update
    set_wsk_yaml
    helm install $owdev $openwhisk/openwhisk -n $openwhisk --create-namespace -f wsk.yaml 
    # helm ls # helm status $owdev -n $openwhisk
}

set_tools(){
    set_helm3
    set_wsk_cli
    
    set_kind
    set_k8s_cli
}

set_openwhisk(){
    set_tools

    # docker ps -a 
    apiHostName=localhost
    apiHostPort=31001

    create_k8scluster

    # Deploy OpenWhisk with Helm
    deploy_wsk_cluster

    # Once the 'owdev-install-packages' Pod is in the `Completed` state, your OpenWhisk deployment is ready to be used.
    kubectl get pods -o wide -A # kubectl get po -A  # kubectl get pods -n $openwhisk --watch    

    # kubectl logs <$pod_name> -n $openwhisk
    # kubectl describe pod <$pod_name>  --namespace=$openwhisk
    docker ps
    kubectl describe node  | grep InternalIP: | awk '{print $2}'
    # kubectl describe node $cluster_name-worker  | grep InternalIP: | awk '{print $2}'
    config_wsk_cli

    # kubectl label nodes --all openwhisk-role=invoker # for single node in the cluster
}

set_pyfile(){
### TODO: re-write py file
echo '
import example
if __name__ == "__main__":
    example.multiply(2,4)' > hello.py
echo 'def __bootstrap__():
   global __bootstrap__, __loader__, __file__
   import sys, pkg_resources, imp
   __file__ = pkg_resources.resource_filename(__name__,\'example.so\')
   __loader__ = None; del __bootstrap__, __loader__
   imp.load_dynamic(__name__,__file__)
__bootstrap__()' > example.py
}

set_cmakefile(){
echo 'cmake_minimum_required(VERSION 3.13)
set(PYBIND11_PYTHON_VERSION 3.5 CACHE STRING "")
project(example LANGUAGES CXX)
find_package(Python COMPONENTS Interpreter Development REQUIRED)
include(FetchContent)
	FetchContent_Declare(
		pybind11
		GIT_REPOSITORY https://github.com/pybind/pybind11.git
		GIT_TAG        v2.6.2
		GIT_SHALLOW    TRUE
	)
	FetchContent_MakeAvailable(pybind11)
pybind11_add_module(example example.cpp)
set(CMAKE_SHARED_MODULE_PREFIX "")
if(PYBIND_LIB)
    add_definitions(-DPYBIND)

    find_package(PythonLibs)
    include_directories(${PYTHON_INCLUDE_DIRS})
    target_include_directories(example PUBLIC include)
endif()
'>CMakeLists.txt
}

set_cppfile(){
echo '#include <pybind11/pybind11.h>
int multiply(int i, int j) {
    return i * j;
}

namespace py = pybind11;

PYBIND11_MODULE(example, m) {
    m.doc() = "pybind11 example plugin"; // optional module docstring
    m.def("multiply", &multiply, "A function which multiplies two numbers");
}'>example.cpp

echo '#include <pybind11/pybind11.h>
namespace py = pybind11
'>example.h
}

set_dockerfile(){
# This dockerfile is for multi-stage building
echo "FROM debian:buster AS base
RUN set -ex;         \
    apt-get update;  \
    apt-get install -y libzmq5

FROM base AS builder
RUN set -ex;   \
    apt-get update; \
    apt-get install -y g++ wget libzmq3-dev libblkid-dev e2fslibs-dev libboost-all-dev libaudit-dev apt-utils build-essential; \
    apt-get install -y --no-install-recommends --no-install-suggests cmake git; \
    git config --global http.sslverify false;\
    git clone https://gitlab.kitware.com/cmake/cmake.git; \
    cd cmake; git checkout tags/v3.14.7; rm -rf build; \
    mkdir build; cd build; \
    cmake -DCMAKE_USE_OPENSSL=OFF ..; cmake --build .; cpack -G DEB; apt remove -y cmake-data; dpkg -i cmake-3.14.7-Linux-x86_64.deb
    
RUN wget --no-check-certificate https://www.python.org/ftp/python/3.5.0/Python-3.5.0.tar.xz; \
 tar xf Python-3.5.0.tar.xz; cd /Python-3.5.0; ./configure --enable-shared; make; make install; ./configure --enable-optimizations; make; make install

COPY example_draft/. /notebooks/ 
RUN cd /notebooks;  \
    cmake . ; \
    make

FROM openwhisk/python3aiaction:latest AS runtime
COPY --from=builder /notebooks /notebooks
RUN mv example.*.so example.so
" > $dockerfile.Dockerfile

# This dockerfile is for single-stage building
echo "FROM openwhisk/python3aiaction:latest AS runtime
RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends --no-install-suggests cmake git
COPY . /notebooks
RUN git clone https://gitlab.kitware.com/cmake/cmake.git; cd cmake; git checkout tags/v3.14.7; \
    mkdir build; cd build; cmake ..; cmake --build .; cpack -G DEB; apt remove -y cmake-data; dpkg -i cmake-3.14.7-Linux-x86_64.deb; \
    cd /notebooks;  \
    cmake . ; \
    make
" > single_stage_build.Dockerfile
}

create_docker_image(){
    set_docker
    set_dockerfile
    set_cmakefile
    set_cppfile

    docker build -t $docker_image -f $dockerfile.Dockerfile $PWD
    docker image tag $docker_image $docker_user/$docker_image
    docker push $docker_user/$docker_image:latest
}

create_invoke_wsk_action(){
    wsk -i action create $action_name --docker $docker_user/$docker_image:latest # wsk -i action create $action_name --docker $docker_user/$docker_image:latest $pythonfile -d --web true --timeout 80000

    # wsk -i action invoke $action_name -b --param name "alex" --debug 
    wsk -i list 
    time wsk -i action invoke $action_name -b --param name "alex" 
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

kubectl logs $pod_name -n $openwhisk

# Debug actions
wsk -i activation get $action_id
}

rest_api(){
# wsk -i list
# wsk -i list -v
# wsk -i namespace list -v
if [ ! -n "$apiHostName" ]; then read -p "Your api host name? e.g. localhost" apiHostName; fi # apiHostName=localhost
if [ ! -n "$apiHostPort" ]; then read -p "Your api host port? e.g. 31001:" apiHostPort; fi # apiHostPort=31001
if [ ! -n "$openwhisk" ]; then read -p "Your namespace? e.g. openwhisk:" openwhisk; fi # openwhisk=openwhisk / default / _
if [ ! -n "$action_name" ]; then read -p "Your Openwhisk Action name? e.g. func_1:" action_name; fi
if [ ! -n "$inputs" ]; then read -p "Your inputs? e.g. '{\"name\":\"John\"}':" inputs; fi # inputs='{"name":"John"}'
APIHOST=$apiHostName:$apiHostPort 
namespace=_
curl -insecure "https://$APIHOST/api/v1/namespaces/${namespace}/actions/${action_name}?blocking=true&result=true" -X POST -H "Content-Type: application/json" -d ${inputs}

AUTH=`wsk -i property get --auth |  awk '{print $3}'`
}

clean_up(){
    wsk -i action delete $action_name
    helm uninstall $owdev -n $openwhisk
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
    owdev=test-cpp  # deployment name, Your named release
    openwhisk=openwhisk  # namespace
    export PATH=$PATH:$PWD

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
