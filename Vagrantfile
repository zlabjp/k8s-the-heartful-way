# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

public_key = nil
[ENV['SSH_PUBLIC_KEY'], "~/.ssh/id_rsa.pub", "~/.ssh/id_dsa.pub"].each do |p_key|
  if p_key
    p_key = File.expand_path(p_key)
    if File.file?(p_key)
      public_key = open(p_key).read
      break
    end
  end
end

unless public_key
  raise "Please specify ssh public key using following env: SSH_PUBLIC_KEY"
end

SCRIPT = <<-EOF
echo "#{public_key}" >> ~vagrant/.ssh/authorized_keys
EOF

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/bionic64"

  [[:master01, 101]].each do |master|
    config.vm.define master[0] do |m|
      m.vm.hostname = master[0].to_s
      m.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--memory", "2048"]
      end

      m.vm.network :private_network, ip: "192.168.43.#{master[1]}"

      m.vm.provision :shell, inline: SCRIPT
      m.vm.provision "docker" do |d|
        d.run "quay.io/coreos/etcd:v3.2.24",
          auto_assign_name: false,
          daemonize: true,
          cmd: [
            "/usr/local/bin/etcd",
            "--data-dir=/etcd-data --name node1",
            "--initial-advertise-peer-urls http://192.168.43.#{master[1]}:2380",
            "--listen-peer-urls http://192.168.43.#{master[1]}:2380",
            "--advertise-client-urls http://192.168.43.#{master[1]}:2379",
            "--listen-client-urls http://192.168.43.#{master[1]}:2379",
            "--initial-cluster node1=http://192.168.43.#{master[1]}:2380",
          ].join(' '),
          args: [
            "--name etcd",
            "-p 2379:2379",
            "-p 2380:2380",
            "--net=host",
            "--volume=/var/lib/etcd:/etcd-data",
          ].join(' ')
      end
    end
  end

  [[:node01, 111], [:node02, 112]].each do |worker|
    config.vm.define worker[0] do |w|
      w.vm.hostname = worker[0].to_s
      w.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--memory", "2048"]
      end

      w.vm.network :private_network, ip: "192.168.43.#{worker[1]}"

      w.vm.provision :shell, inline: SCRIPT
      w.vm.provision "docker", images: ["busybox"]
    end
  end

end
