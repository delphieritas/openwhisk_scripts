# openwhisk_scripts
This README file is to explain and describe how to deploy Openwhisk on Kubernetes using fuctions provided in ```./start.sh``` script, which requires Ubuntu system.
This script is automated, and users are supposed to configure a few name parameters then run ```bash ./start.sh start``` only.

Given cases to use functions separately, explanations and usages are also given in following sections.


## Environment Setup
The requisitions are ```'git', 'curl', 'unzip', 'wget'```.
If you start from a totally new Ubuntu system, we provide the following functions for your easy usage:
```
set_git
set_cert
set_curl
set_unzip
set_wget
```

## Tools Preparition
Run ```bash ./start.sh set_tools```

Before you start, let's introduce 4 tools: ```'wsk', 'helm', 'kind', 'kubectl'```:
```
wsk: an Openwhisk Command-line Interface (CLI)
     https://github.com/apache/openwhisk-cli
     
helm: a package manager for Kubernetes, it is to install openwhisk repo chart and to deploy openwhisk on k8s
      https://helm.sh/docs/helm/helm/

kind: a tool for running local Kubernetes clusters using Docker container “nodes”, it is to create k8s cluster
      https://kind.sigs.k8s.io

kubectl: a Kubernetes cluster manager, it is to retrieve k8s cluster information
         https://kubernetes.io/docs/reference/kubectl/kubectl/
```
It is necessary to have these 4 tools. you should check your tool versions or install tools using below functions provided in ```./start.sh```:
```
set_helm3: install helm3
set_kind: install KIND
set_wsk_cli: install wsk Cli
set_k8s_cli: install kubectl
set_k8s: initialize k8s
```

## Deploy
Run ```bash ./start.sh set_openwhisk```. 

To break down the steps in details, ```set_openwhisk``` includes :
```
    'set_k8s_yaml': a yaml file creation funciton, and 
    'create_k8scluster': a Kubernetes cluster creation fucntion accordingly with tools, 'kind' and 'kubectl'
    'deploy_wsk_cluster': deploy openwhisk on Kubernetes cluster with 'helm'
    'config_wsk_cli': cinfigure the API host and port for 'wsk' Cli
``` 
    
## Create && Invoke Openwhisk Action
Run ```bash ./start.sh wsk_cli_create_invoke```.

```wsk_cli_create_invoke``` wraps the following steps:
```
    'set_pyfile': write a python file containing the main function
    'create_docker_image': write a Dockerfile for single node openwhisk action
    'create_invoke_wsk_action': create and invoke Openwhisk action using 'wsk' Cli
```
