FROM golang

RUN wget https://github.com/vmware-tanzu/tanzu-cli/releases/download/v1.1.0/tanzu-cli-linux-amd64.tar.gz -P /tmp && \
tar -zxvf /tmp/tanzu-cli-linux-amd64.tar.gz -C /tmp && mv /tmp/v1.1.0/tanzu* /usr/local/bin/tanzu && \
chmod +x /usr/local/bin/tanzu && \
export TANZU_CLI_CEIP_OPT_IN_PROMPT_ANSWER=yes && tanzu config eula accept && tanzu plugin install --group vmware-tap/default

RUN  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
mv kubectl /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

RUN wget https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64 -P /usr/local/bin && \
mv /usr/local/bin/jq* /usr/local/bin/jq && chmod +x /usr/local/bin/jq

RUN wget https://github.com/mikefarah/yq/releases/download/v4.40.2/yq_linux_amd64 -P /usr/local/bin && \
mv /usr/local/bin/yq* /usr/local/bin/yq && chmod +x /usr/local/bin/yq;

CMD [sh]