#docker build -t ansible --platform linux/amd64 --build-arg vm_ip_address="<vm_ip_address>" --build-arg ansible_tag="<tag>" .
#docker run -it --rm -v $(dirname $SSH_AUTH_SOCK):/ssh-agent -v ~/.ssh:/root/.ssh -v ~/.ssh/docker_config:/root/.ssh/config -e SSH_AUTH_SOCK=/ssh-agent/Listeners ansible

FROM python:3.12
ENV DEBIAN_FRONTEND=noninteractive
ARG vm_ip_address
ARG ansible_tag
ENV VM_IP_ADDRESS=${vm_ip_address}
ENV ANSIBLE_TAG=${ansible_tag:-""}
RUN apt update && apt install --no-install-recommends -y openssh-client
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan 138.68.75.47 >> ~/.ssh/known_hosts
COPY ../p3/scripts /ansible
WORKDIR /ansible
RUN pip install ansible-core passlib
RUN ansible-galaxy install -r requirements.yaml

ENTRYPOINT ["bash", "run.sh"]
