SHELL := bash

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BUILD_DIR ?= $(ROOT_DIR)/.build
OUTPUT_DIR ?= $(ROOT_DIR)/.output

NAME ?= empty
VERSION ?= 0.1.0
TIMESTAMP := $(shell date +%s)
BOX_NAME ?= "$(NAME)-$(VERSION)-virtualbox.box"
BOX_NAME_LV ?= "$(NAME)-$(VERSION)-libvirt.box"
VM_NAME ?= $(NAME)-$(VERSION)-$(TIMESTAMP)

.PHONY: default
default: all

.PHONY: dirs
dirs: ## Create build directory
	@@mkdir -p "$(BUILD_DIR)" "$(OUTPUT_DIR)"

.PHONY: build-vb
build-vb: clean dirs ## Create VirtualBox Vagrant Box
	VBoxManage createvm --name "$(VM_NAME)" --ostype "Linux_64" --register
	VBoxManage modifyvm "$(VM_NAME)" --natdnshostresolver1 on
	VBoxManage modifyvm "$(VM_NAME)" --natdnsproxy1 on
	VBoxManage modifyvm "$(VM_NAME)" --firmware efi
	VBoxManage modifyvm "$(VM_NAME)" --nictype1 virtio
	VBoxManage modifyvm "$(VM_NAME)" --macaddress1 080000CAFE01
	VBoxManage modifyvm "$(VM_NAME)" --graphicscontroller vmsvga
	VBoxManage modifyvm "$(VM_NAME)" --boot1 net --boot2 disk --boot3 none --boot4 none
	VBoxManage createmedium disk --filename "${BUILD_DIR}/empty.vdi" --size 8000 --format VDI --variant Standard
	VBoxManage storagectl "$(VM_NAME)" --name SAS --add sas --controller LSILogicSAS --portcount 1
	VBoxManage storageattach "$(VM_NAME)" --storagectl SAS --port 1 --type hdd --medium "$(BUILD_DIR)/empty.vdi"
	vagrant package --base "$(VM_NAME)" --output "$(OUTPUT_DIR)/$(BOX_NAME)"
	@while [ ! -s $(OUTPUT_DIR)/$(BOX_NAME) ]; do echo '.'; done;
	VBoxManage unregistervm "$(VM_NAME)" --delete

.PHONY: build-lv
build-lv: dirs ## Create Libvirt Vagrant Box
	@cp vdisk1 $(BUILD_DIR)/box.img
	@cp Vagrantfile.libvirt $(BUILD_DIR)/Vagrantfile
	@cp metadata.json $(BUILD_DIR)
	@cd $(BUILD_DIR); tar cvzf $(OUTPUT_DIR)/$(BOX_NAME_LV) metadata.json Vagrantfile box.img

.PHONY: clean
clean: ## Cleanup
	@( VBoxManage showmediuminfo disk "$(BUILD_DIR)/empty.vdi" >/dev/null 2>&1 && VBoxManage closemedium disk "$(BUILD_DIR)/empty.vdi" --delete ) || true
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR)

.PHONY: all
all: build-vb build-lv shasums ## Build all boxes and print SHA sums

.PHONY: shasums
shasums: ## Print SHA sums
	@echo ""
	@shasum -a 512 $(OUTPUT_DIR)/*.box

.PHONY: help
help: ## This help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' | sort
