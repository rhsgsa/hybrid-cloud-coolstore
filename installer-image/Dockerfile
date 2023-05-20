FROM quay.io/centos/centos@sha256:06cfbf69d99f47f45f327d18fec086509ca0c74afdb178fb8c5bc45184454cc0

RUN \
  dnf update -y \
  && \
  dnf install -y git make jq \
  && \
  mkdir /tmp/install \
  && \
  curl -Lo /tmp/install/oc.tgz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.12.18/openshift-client-linux-4.12.18.tar.gz \
  && \
  cd /tmp/install \
  && \
  tar -zxf oc.tgz \
  && \
  mv oc kubectl /usr/local/bin/ \
  && \
  rm -rf /tmp/install \
  && \
  chmod g+rwx /usr/local/bin/oc /usr/local/bin/kubectl \
  && \
  useradd -d /home/install -m -u 1001 -g 0 install \
  && \
  chmod g+rwx /home/install \
  && \
  find /home/install/ -type f -exec chmod g+rw {} \;

USER 1001
WORKDIR /home/install
ENTRYPOINT /bin/bash
