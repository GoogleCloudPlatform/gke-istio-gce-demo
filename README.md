# Istio Service Mesh expansion to GCE

## Table of Contents
<!--ts-->
* [Introduction](#introduction)
* [Architecture](#architecture)
  * [Istio Overview](#istio-overview)
    * [Istio Control Plane](#istio-control-plane)
    * [Istio Data Plane](#istio-data-plane)
  * [BookInfo Sample Application](#bookinfo-sample-application)
  * [Architecture](#architecture-1)
* [Prerequisites](#prerequisites)
  * [Supported Operating Systems](#supported-operating-systems)
  * [Deploying Demo from Google Cloud Shell](#deploying-demo-from-google-cloud-shell)
  * [Deploying Demo without Cloud Shell](#deploying-demo-without-cloud-shell)
* [Deployment](#deployment)
* [Validation](#validation)
* [Tear Down](#tear-down)
* [Relevant Material](#relevant-material)
<!--te-->

## Introduction

In this demo, we leverage [Google Kubernetes
Engine](https://cloud.google.com/kubernetes-engine/) (Kubernetes Engine) and
[Google Compute Engine](https://cloud.google.com/compute/) (GCE) to learn more
about how Istio can manage services that reside in the network outside of the
Kubernetes Engine environment. This demo uses Kubernetes Engine to construct a
typical Istio infrastructure and then setup a GCE instance running a
[MySQL](https://www.mysql.com/) microservice that will be integrated into the
Istio infrastructure. We will use the sample [BookInfo](https://istio.io/docs/examples/bookinfo/) application and extend it
by using the MySQL microservice to house book reviewer ratings. The demo serves
as a learning tool and addresses the use case of users who want to leverage
Istio to manage other services in their
[Google Cloud Platform](https://cloud.google.com/) (GCP) environment that may
not be ready for migration to Kubernetes Engine just yet.

## Architecture

### Istio Overview

Istio has two main pieces that create the service mesh: the control plane and
the data plane.

#### Istio Control Plane

The control plane is made up of the following set of components that act
together to serve as the hub for the infrastructure's service management:

- **Mixer**: a platform-independent component responsible for enforcing access
  control and usage policies across the service mesh and collecting telemetry
  data from the Envoy proxy and other services

- **Pilot**: provides service discovery for the Envoy sidecars, traffic
  management capabilities for intelligent routing, (A/B tests, canary
  deployments, etc.), and resiliency (timeouts, retries, circuit breakers,
  etc.)

- **Citadel**: provides strong service-to-service and end-user authentication
  using mutual TLS, with built-in identity and credential management.

#### Istio Data Plane

The data plane comprises all the individual service proxies that are
distributed throughout the infrastructure. Istio uses
[Envoy](https://www.envoyproxy.io/) with some Istio-specific extensions as its
service proxy. It mediates all inbound and outbound traffic for all services in
the service mesh. Istio leverages Envoy’s many built-in features such as
dynamic service discovery, load balancing, TLS termination, HTTP/2 & gRPC
proxying, circuit breakers, health checks, staged roll-outs with
percentage-based traffic splits, fault injection, and rich metrics.

### BookInfo Sample Application

The sample [BookInfo](https://istio.io/docs/guides/bookinfo.html)
application displays information about a book, similar to a single catalog entry
of an online book store. Displayed on the page is a description of the book,
book details (ISBN, number of pages, and so on), and a few book reviews.

The BookInfo application is broken into four separate microservices and calls on
various language environments for its implementation:

- **productpage** - The productpage microservice calls the details and reviews
  microservices to populate the page.
- **details** - The details microservice contains book information.
- **reviews** - The reviews microservice contains book reviews. It also calls the
  ratings microservice.
- **ratings** - The ratings microservice contains book ranking information that
  accompanies a book review.

There are 3 versions of the reviews microservice:

- **Version v1** doesn’t call the ratings service.
- **Version v2** calls the ratings service, and displays each rating as 1 to 5
  black stars.
- **Version v3** calls the ratings service, and displays each rating as 1 to 5
  red stars.

![](./images/bookinfo.png)

To learn more about Istio, please refer to the
[project's documentation](https://istio.io/docs/).

### Architecture

The pods and services that make up the Istio control plane are the first components of the architecture that will be installed into Kubernetes Engine. An Istio service proxy is installed along with each microservice during the installation of the BookInfo application. At this point, in addition to the application microservices there are two tiers that make up the Istio architecture: the Control Plane and the Data Plane. 

In the diagram, note:
* All input and output from any BookInfo microservice goes through the service proxy.
* Each service proxy communicates with each other and the Control plane to
  implement the features of the service mesh, circuit breaking, discovery, etc.
* The Mixer component of the Control Plane is the conduit for the telemetry
  add-ons to get metrics from the service mesh.
* The Istio ingress component provides external access to the mesh.
* The environment is setup in the Kubernetes Engine default network.

![](./images/istio-gke-gce.png)

## Prerequisites

A Google Cloud account and a project with billing enabled are required for this demo to function. If you do not have a Google Cloud account please sign up for a free trial [here](https://cloud.google.com).

### Supported Operating Systems

This demo can be run from MacOS, Linux, or, alternatively, directly from [Google Cloud Shell](https://cloud.google.com/shell/docs/). The latter option is the simplest as it only requires browser access to GCP and no additional software is required. Instructions for both alternatives can be found below.

### Deploying Demo from Google Cloud Shell

_NOTE: This section can be skipped if the cloud deployment is being performed without Cloud Shell, for instance from a local machine or from a server outside GCP._

[Google Cloud Shell](https://cloud.google.com/shell/docs/) is a browser-based terminal that Google provides to interact with your GCP resources. It is backed by a free Compute Engine instance that comes with many useful tools already installed, including everything required to run this demo.

Click the button below to open the demo in your Cloud Shell:

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/open?git_repo=https%3A%2F%2Fgithub.com%2FGoogleCloudPlatform%2Fgke-istio-gce-demo&page=editor&tutorial=README.md)

To prepare [gcloud](https://cloud.google.com/sdk/gcloud/) for use in Cloud Shell, execute the following command in the terminal at the bottom of the browser window you just opened:

```console
gcloud init
```

Respond to the prompts and continue with the following deployment instructions. The prompts will include the account you want to run as, the current project, and, optionally, the default region and zone. These configure Cloud Shell itself-the actual project, region, and zone, used by the demo will be configured separately below.

### Deploying Demo without Cloud Shell

_NOTE: If the demo is being deployed via Cloud Shell, as described above, this section can be skipped._

For deployments without using Cloud Shell, you will need to have access to a computer providing a  [bash](https://www.gnu.org/software/bash/) shell with the following tools installed:

* [Google Cloud SDK (v204.0.0 or later)](https://cloud.google.com/sdk/downloads)
* [kubectl (v1.10.0 or later)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [git](https://git-scm.com/)

Use `git` to clone this project to your local machine:

```shell
git clone --recursive https://github.com/GoogleCloudPlatform/gke-istio-gce-demo
```

Note that the `--recursive` argument is required to download dependencies provided via a git submodule.

When downloading is complete, change your current working directory to the new project:

```shell
cd gke-istio-gce-demo
```

Continue with the instructions below, running all commands from this directory.

## Deployment

_NOTE: The following instructions are applicable for deployments performed both with and without Cloud Shell._

Copy the `properties` file to `properties.env` and set the following variables in the `properties.env` file:
 * `PROJECT` - the name of the project you want to use
 * `REGION` - the region in which to locate all the infrastructure
 * `ZONE` - the zone in which to locate all the infrastructure

Run the following command:

```shell
./setup.sh
```

  Press `RETURN` for each of the following prompts, if they are displayed midway through the script:

```console
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

The script should deploy all of the necessary infrastructure and install Istio. The script will end with a line like this, though the IP address will likely be different:
```
Update istio service proxy environment file
104.196.243.210/productpage
```

You can open this URL in your browser and see the simple web application provided by the demo.

## Validation

To validate that everything is working correctly, first open your browser to the URL provided at the end of the setup script. Once the ratings service is running correctly, run:

```shell
./validate.sh <STARS>
```

and substitute `<STARS>` for the number of stars to return. The value of `<STARS>` must be an integer between 1 and 5.

If you refresh the page in your browser, the first rating should display the number of stars you entered. This shows that the rating has made it from the database to the ratings service. While the database microservice isn't contained within the GKE cluster, it works seamlessly via the Istio data plane.

## Tear Down

To tear down the resources created by this demo, run

```console
./teardown.sh
```

NOTE: Keep an eye on quotas. The teardown script deletes resources of which it is aware but it is possible some resources were created in setup and not torn down.

## Relevant Material

This demo was created with help from the following links

- https://cloud.google.com/kubernetes-engine/docs/tutorials/istio-on-gke
- https://cloud.google.com/compute/docs/tutorials/istio-on-compute-engine
- https://istio.io/docs/guides/bookinfo.html
- https://istio.io/docs/setup/kubernetes/mesh-expansion.html
- https://istio.io/docs/guides/integrating-vms.html


**This is not an officially supported Google product**
