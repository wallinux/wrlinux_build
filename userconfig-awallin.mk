
LINUX_TAG	?= 17.04
AW_LOOP		?= 3

docker.prepare.$(USER)::
	$(MAKE) aw.prepare	

aw.test: configure
	$(MAKE) -s -C $(BUILDDIR) bbc BBCMD="bitbake -c cleanall virtual/kernel"
	$(Q)time make -s -C $(BUILDDIR) bbc BBCMD="bitbake virtual/kernel"


aw.test.all:
#	$(MAKE) aw.test
	$(MAKE) docker.make.aw.test

aw.test.loop:
	$(Q)for i in $$(seq 1 $(AW_LOOP)); do \
		make aw.test.all; \
	done

aw.prepare:
	$(call run-docker-exec, root, , sh -c "apt install -y bsdmainutils time" )
	$(call run-docker-exec, $(USER), , ls -al ~/ )
	$(call run-docker-exec, $(USER), , sh -c "echo PS1=\'\\\u:\\\W\\\$$ \' >> $$HOME/.bashrc" )

PKG=linux-windriver-4.1-r0
aw.testresult:
	$(Q)cd $(BUILDDIR)/bitbake_build/tmp/buildstats/virtual/kernel:do_build-$(BSP); \
		for builds in $$(ls -1); do \
			cd $$builds; \
			rows=$$(ls -1 | wc -l); \
			if [ "$$rows" = "2" ]; then \
				echo $$builds; \
				grep -e "Elapsed time" -e "CPU usage" build_stats; \
				grep time $$(ls -1 $(PKG)/*) | cut -d: -f3- | sed "s/Elapsed time://" | column -t; \
			fi; \
			cd ..; \
		done

aw.tr:
	$(Q)cd $(BUILDDIR)/bitbake_build/tmp/buildstats/virtual/kernel:do_build-$(BSP); \
		echo -e "\n$(BUILDDIR)"; \
		for builds in $$(ls -1); do \
			cd $$builds; \
			rows=$$(ls -1 | wc -l); \
			if [ "$$rows" = "2" ]; then \
				grep time $$(ls -1 $(PKG)/*) | grep do_package_qa | cut -d: -f3- | sed "s/Elapsed time://" | column -t | xargs echo $$builds: ; \
			fi; \
			cd ..; \
		done

aw.tr.all:
	$(MAKE) -s aw.tr OUTDIR=$(TOP)/out
	$(Q)for dir in $$(ls -d $(TOP)/out_docker.*); \
		do make -s aw.tr OUTDIR=$$dir; \
	done 
