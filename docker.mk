# docker.mk

WRLINUX_CONTAINER  ?= $(USER)_$(WIND_VER)_$(LINUX_DISTRO)_$(LINUX_TAG)
WRLINUX_DISTRO	   ?= $(WIND_VER)
WRLINUX_IMAGE	   ?= $(WRLINUX_DISTRO):$(LINUX_DISTRO)-$(LINUX_TAG)
WRLINUX_HOSTNAME   ?= docker-$(LINUX_DISTRO)-$(LINUX_TAG).wrlinux.com
WRLINUX_DOCKERFILE ?= Dockerfiles/Dockerfile.$(LINUX_DISTRO)-$(LINUX_TAG)

LINUX_DISTRO	 ?= ubuntu
LINUX_TAG	 ?= 16.04
LINUX_IMAGE	 ?= $(LINUX_DISTRO):$(LINUX_TAG)

DOCKER		 ?= $(Q)docker

define run-docker-exec
	$(DOCKER) exec -u $(1) $(2) $(WRLINUX_CONTAINER) $(3)
endef

docker.%: export OUTDIR=$(TOP)/out_docker.$(LINUX_DISTRO)-$(LINUX_TAG)

docker.build: $(WRLINUX_DOCKERFILE)
	$(Q)if [ "$$(docker images -q $(LINUX_IMAGE) 2> /dev/null)" == "" ]; then \
		docker pull $(LINUX_IMAGE); \
	fi
	$(Q)if [ "$$(docker images -q $(WRLINUX_IMAGE) 2> /dev/null)" == "" ]; then \
		docker build -f $< -t "$(WRLINUX_IMAGE)" .; \
	fi

docker.prepare:
	$(DOCKER) start $(WRLINUX_CONTAINER)
	$(eval host_timezone=$(shell cat /etc/timezone))
	$(call run-docker-exec, root, , useradd --shell /bin/bash -m -u $(shell id -u) $(USER) -g users || true )
	$(call run-docker-exec, root, , sh -c "echo $(host_timezone) > /etc/timezone" )
	$(call run-docker-exec, root, , ln -sfn /usr/share/zoneinfo/$(host_timezone) /etc/localtime )
	$(call run-docker-exec, root, , dpkg-reconfigure -f noninteractive tzdata )
	$(MAKE) docker.prepare.$(USER)
	$(DOCKER) stop $(WRLINUX_CONTAINER)
	$(ECHO) "WIND_INSTALL_BASE = $(WIND_INSTALL_BASE)"  > hostconfig-$(WRLINUX_HOSTNAME).mk
	$(ECHO) 'OUTDIR ?= $$(TOP)/out_docker.$(LINUX_DISTRO)-$(LINUX_TAG)' >> hostconfig-$(WRLINUX_HOSTNAME).mk


docker.prepare.$(USER)::
	$(ECHO) "Run user specific prepare commands"

docker.create: docker.build
	$(Q)if [ -z $$(docker ps -a -q -f name=$(WRLINUX_CONTAINER)) ]; then \
		docker create -P --name $(WRLINUX_CONTAINER) \
		-v $(WIND_LX_HOME):$(WIND_LX_HOME):ro \
		-v $(GITROOT):$(GITROOT):delegated \
		-h $(WRLINUX_HOSTNAME) \
		--dns=8.8.8.8 \
		-i $(WRLINUX_IMAGE); \
		make docker.prepare; \
	fi

docker.start: docker.create
	$(DOCKER) start $(WRLINUX_CONTAINER)

docker.stop:
	$(Q)if [ ! -z $$(docker ps -q -f name=$(WRLINUX_CONTAINER)) ]; then \
		docker stop $(WRLINUX_CONTAINER); \
	fi

docker.rm:
	$(Q)if [ ! -z $$(docker ps -a -q -f name=$(WRLINUX_CONTAINER)) ]; then \
		docker rm $(WRLINUX_CONTAINER); \
	fi

docker.rmi:
	$(Q)if [ "$$(docker images -q $(WRLINUX_IMAGE) 2> /dev/null)" != "" ]; then \
		docker rmi $(WRLINUX_IMAGE); \
	fi

docker.clean:
	$(MAKE) docker.stop || true
	$(MAKE) docker.rm || true
	$(MAKE) docker.rmi

docker.shell: docker.start
	$(call run-docker-exec, $(USER), -it, /bin/bash -c "cd $(TOP); exec '$${SHELL:-sh}'")

docker.rootshell: docker.start
	$(call run-docker-exec, root, -it, /bin/bash -c "cd /root; exec '$${SHELL:-sh}'")

docker.make.%: docker.start
	$(call run-docker-exec, $(USER), -t, make -s -C $(TOP) $*)

docker.test: docker.start
	$(MAKE) docker.make.configure

docker.help:
	$(ECHO) "\n--- docker ---"
	$(ECHO) " CONTAINER_NAME=$(WRLINUX_CONTAINER) IMAGE=$(WRLINUX_IMAGE)"
	$(ECHO) " docker.create	- create container"
	$(ECHO) " docker.start	- start container"
	$(ECHO) " docker.stop	- stop container"
	$(ECHO) " docker.rm	- Remove container"
	$(ECHO) " docker.rmi	- Remove image"
	$(ECHO) " docker.shell	- start a bash shell in the container"
	$(ECHO) " docker.make.*	- Run make inside container, e.g. make docker.make.all"

help:: docker.help
