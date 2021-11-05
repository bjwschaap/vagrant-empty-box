# vagrant-empty-box

Run `make` to generate an empty vagrant box that can be used in Vagrant for
e.g. testing PXE booting. Currently the Virtualbox and Libvirt providers
are supported.

When using this box in Vagrant you'll get a box and Vagrantfile template
that are ready to be used for iPXE booting on a host-only network.

## Usage

Run:

- `make` or `make all` to build all Vagrant boxes.
- `make build-vb` to only build Virtualbox box.
- `make build-lv` to only build Libvirt box.
- `make clean` to clean up build artifacts.
- `make shasums` to output all SHA sums (for manually uploading to Vagrant Cloud)

## Example Vagrantfile

This example Vagrantfile will simply boot a VM with an empty
8GB HD (from this `empty` box), and iPXE boot enabled.

**_Please Note_** You must have the Virtualbox extension pack
installed in order to use (i)PXE booting!

```ruby
Vagrant.configure("2") do |config|
  
  config.vagrant.plugins = ["vagrant-dummy-communicator"]

  config.vm.define "pxe-test" do |pxe|
    pxe.vm.box = "pace/empty"

    # Directories (un-)shared between host and guest
    pxe.vm.synced_folder ".", "/vagrant", disabled: true

    # Networking
    pxe.vm.network "private_network",
      ip: "192.168.33.101",
      adapter: "1",
      nic_type: "virtio",
      auto_config: false,
      :libvirt__dhcp_enabled => false

    # Dummy communicator is needed in order for Vagrant to skip
    # waiting for SSH to be available. Otherwise it will 'hang'
    # on waiting for SSH/boot to be ready...
    pxe.vm.communicator = "dummy"

    pxe.vm.provider "virtualbox" do |vb|
      vb.name = "pxe-test"
      vb.gui = true
      vb.memory = 512
      vb.cpus = 1
      # Set fixed MAC, might be handy for iPXE scripts etc.
      vb.customize ["modifyvm", :id, "--macaddress1", "080000CAFE01"]
      vb.linked_clone = true
    end

    pxe.vm.provider "libvirt" do |lv|
      lv.title = "pxe-test"
      lv.cpus = 1
      lv.memory = 512
      lv.nested = true
      lv.boot "network"
    end

    # Don't update guest tools, since openvm tools are installed
    if Vagrant.has_plugin?("vagrant-vbguest")
      pxe.vbguest.no_install = true
      pxe.vbguest.no_remote = true
      pxe.vbguest.auto_update = false
    end
  end
end
```
