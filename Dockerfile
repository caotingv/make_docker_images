FROM ubuntu:20.04 as os-focal
ARG OS_VERSION=focal
ARG DEP_PACKAGES="apt-transport-https ca-certificates curl wget gnupg dpkg-dev software-properties-common"

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apt update \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL "https://download.docker.com/linux/debian/gpg" | apt-key add - \
    && echo "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu ${OS_VERSION} stable" > /etc/apt/sources.list.d/docker.list\
    && curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list\
    && add-apt-repository --yes --update ppa:ansible/ansible\
    && apt update -qq

WORKDIR /ubuntu/${OS_VERSION}
COPY packages.yaml packages.yaml 

RUN yq eval packages.yaml -j | jq -r '.common[],.apt[],.ubuntu[]' | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /ubuntu/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

FROM httpd:latest
COPY --from=os-focal /ubuntu /usr/local/apache2/htdocs/

