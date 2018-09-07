SHELL:=/bin/bash
none:


# ~~~~~ CREATE SINGULARITY IMAGE ON MAC USING VAGRANT ~~~~~ #
check-var:
	@test $(VAR) || (echo ">>> ERROR: VAR must be set for this; 'make <recipe> VAR=dir'" ; exit 1)

check-var-dir:
	@[ ! -d "$(VAR)" ] && { echo ">>> ERROR: VAR '$(VAR)' is not a directory" ; exit 1 ; } || :

check-singularityfile:
	@[ ! -f "$(SINGULARITYFILE)" ] && { echo ">>> ERROR: Singularity file '$(SINGULARITYFILE)' does not exist" ; exit 1 ; } || :

check-singularityimage:
	@[ ! -f "$(IMG)" ] && { echo ">>> ERROR: Singularity image file '$(IMG)' does not exist" ; exit 1 ; } || :

Vagrantfile:
	vagrant init singularityware/singularity-2.4

# seems to fix sporadic errors that arise when using Singularity inside Vagrant...
clean-vagrant:
	[ -d .vagrant ] && rm -rf .vagrant || :

SINGULARITYFILE:=$(VAR)/Singularity.$(VAR)
IMG:=$(VAR)/$(VAR).simg
TEST:=
build:
	@$(MAKE) check-var
	@$(MAKE) check-var-dir
	@$(MAKE) check-singularityfile
	@echo ">>> Setting up to build Singularity image in directory: $(VAR)"
	@[ -f "$(IMG)" ] && { echo ">>> Removing previous image file: $(IMG)" ; rm -f "$(IMG)" ; wait $$! ; } ; \
	echo ">>> Output file will be: $(IMG)" && \
	vagrant up build && \
	vagrant ssh build -c "cd /vagrant && sudo singularity build $(IMG) $(SINGULARITYFILE)" && \
	[ -n "$(TEST)" ] && $(MAKE) test || :

test:
	@$(MAKE) check-var
	@$(MAKE) check-var-dir
	@$(MAKE) check-singularityimage
	@echo ">>> Starting Vagrant..." && \
	vagrant up test && \
	vagrant ssh test -c "singularity shell /vagrant/$(IMG)"

USER:=$(shell echo $$USER)
REMOTE:=bigpurple.nyumc.org
REMOTEDIR:=/gpfs/home/$(USER)/containers
sync:
	@$(MAKE) check-var
	@$(MAKE) check-singularityimage
	@echo 'command:'
	@echo 'rsync --dry-run -vrhP -e ssh $(IMG) $(USER)@$(REMOTE):$(REMOTEDIR)'
