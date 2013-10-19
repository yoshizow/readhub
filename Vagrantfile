VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "precise32"
  config.vm.box_url = "http://files.vagrantup.com/precise32.box"

  config.vm.network :private_network, ip: "192.168.33.10"

  config.vm.provider "virtualbox" do |vm|
    vm.customize ["modifyvm", :id, "--cpus", "2"]
    vm.customize ["modifyvm", :id, "--ioapic", "on"]
    vm.customize ["modifyvm", :id, "--memory", "1024"]
  end

  # vagrant-omnibus plugin
  config.omnibus.chef_version = :latest

  # vagrant-berkshelf plugin
  config.berkshelf.enabled = true

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      'rbenv' => {
        'global' => '2.0.0-p247',
        'rubies' => ['2.0.0-p247'],
        'gems' => {
          '2.0.0-p247' => [
            { 'name' => 'bundler' }
          ]
        }
      }
    }

    chef.run_list = [
        "apt",     # perform "apt-get update"
        "readhub"
    ]
  end
end
