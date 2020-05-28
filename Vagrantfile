# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

VAGRANTFILE_API_VERSION = "2"

require 'openssl'
require 'fileutils'
require 'open-uri'

ROOT_DIR = File.dirname(__FILE__)
CACHE_DIR = File.join(ROOT_DIR, "cache")

FileUtils.mkdir_p(CACHE_DIR)

CLUSTER_PRIVATE_KEY = File.join(ROOT_DIR, "id_rsa")
CLUSTER_PUBLIC_KEY  = File.join(ROOT_DIR, "id_rsa.pub")

unless File.file?(CLUSTER_PRIVATE_KEY)
  key = OpenSSL::PKey::RSA.new 2048
  File.open CLUSTER_PRIVATE_KEY, 'wb' do |f|
    f.write key.export(nil, nil)
  end
  File.open CLUSTER_PUBLIC_KEY, 'wb' do |f|
    f.write key.public_key.export(nil, nil)
  end
end

KUBECTL_CACHE = File.join(CACHE_DIR, 'kubectl')
CNI_PLUGIN_CACHE = File.join(CACHE_DIR, 'cni-plugin.tgz')

cluster_ssh_private_key = nil
cluster_ssh_public_key = nil

open(CLUSTER_PRIVATE_KEY) {|io| cluster_ssh_private_key = io.read}
open(CLUSTER_PUBLIC_KEY) {|io| cluster_ssh_public_key = io.read}

unless File.file?(KUBECTL_CACHE)
  open("https://storage.googleapis.com/kubernetes-release/release/v1.18.2/bin/linux/amd64/kubectl") do |i|
    open(KUBECTL_CACHE, 'w') do |o|
      o.write(i.read)
    end
  end
end

unless File.file?(CNI_PLUGIN_CACHE)
  open("https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz") do |i|
    open(CNI_PLUGIN_CACHE, 'w') do |o|
      o.write(i.read)
    end
  end
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/bionic64"

  [[:master01, 101]].each do |master|
    config.vm.define master[0] do |m|
      m.vm.hostname = master[0].to_s
      m.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--memory", "1024"]
      end

      m.vm.network :private_network, ip: "192.168.43.#{master[1]}"

      m.vm.provision :shell, path: "scripts/setup-network.sh"
      m.vm.provision :shell, path: "scripts/install-kubectl.sh"
      m.vm.provision :shell, path: "scripts/install-tools.sh"
      m.vm.provision :shell, path: "scripts/gen-certs.sh"
      m.vm.provision :shell, path: "scripts/gen-kubeconfig.sh"
      m.vm.provision "docker" do |d|
        d.run "quay.io/coreos/etcd:v3.4.3",
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
      m.vm.provision "docker" do |d|
        d.run "k8s.gcr.io/hyperkube:v1.18.2",
        auto_assign_name: false,
        daemonize: true,
        cmd: [
          "kube-apiserver",
          "--authorization-mode=Node,RBAC",
          "--advertise-address=192.168.43.101",
          "--allow-privileged=true",
          "--bind-address=0.0.0.0",
          "--client-ca-file=/etc/kubernetes/secrets/ca.crt",
          "--enable-bootstrap-token-auth=true",
          "--etcd-servers=http://192.168.43.101:2379",
          "--insecure-port=0",
          "--kubelet-certificate-authority=/etc/kubernetes/secrets/ca.crt",
          "--kubelet-client-certificate=/etc/kubernetes/secrets/kubelet-client.crt",
          "--kubelet-client-key=/etc/kubernetes/secrets/kubelet-client.key",
          # "--proxy-client-cert-file=/etc/kubernetes/secrets/front-proxy-client.crt",
          # "--proxy-client-key-file=/etc/kubernetes/secrets/front-proxy-client.key",
          # "--requestheader-client-ca-file=/etc/kubernetes/secrets/front-proxy-ca.crt",
          # "--requestheader-allowed-names=aggregator",
          # "--requestheader-extra-headers-prefix=X-Remote-Extra-",
          # "--requestheader-group-headers=X-Remote-Group",
          # "--requestheader-username-headers=X-Remote-User",
          "--secure-port=6443",
          # "--service-account-key-file=/etc/kubernetes/secrets/service-account.pub",
          "--service-cluster-ip-range=10.254.0.0/16",
          "--tls-cert-file=/etc/kubernetes/secrets/apiserver.crt",
          "--tls-private-key-file=/etc/kubernetes/secrets/apiserver.key",
          "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
          "--v=2"
        ].join(' '),
        args: [
          "--name apiserver",
          "-p 6443:6443",
          "--net=host",
          "--volume=/vagrant/kubernetes:/etc/kubernetes",
          "--volume=/etc/ca-certificates:/etc/ca-certificates",
          "--volume=/usr/share/ca-certificates:/usr/share/ca-certificates",
          "--volume=/usr/local/share/ca-certificates:/usr/local/share/ca-certificates",
        ].join(' ')
      end
      m.vm.provision :shell, path: "scripts/install-prerequisite.sh"
      m.vm.provision :shell, path: "scripts/install-master.sh"
      m.vm.provision :shell, inline: "iptables -P FORWARD ACCEPT"
    end
  end

  [[:inajob, 111], [:yuanying, 112]].each do |worker|
    config.vm.define worker[0] do |w|
      w.vm.hostname = worker[0].to_s
      w.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--memory", "2048"]
        v.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      end

      w.vm.network :private_network, ip: "192.168.43.#{worker[1]}"

      w.vm.provision :shell, path: "scripts/setup-network.sh"
      w.vm.provision :shell, path: "scripts/install-tools.sh"
      w.vm.provision :shell, path: "scripts/install-kubectl.sh"
      w.vm.provision :shell, path: "scripts/install-cni.sh"
      w.vm.provision :shell, path: "scripts/copy-kubeconfig.sh"
      w.vm.provision "docker", images: ["nginx:1.14", "k8s.gcr.io/pause:3.1"] do |d|
        d.build_image "/vagrant/resources/app", args: "-t zlabjp/heartful-app:1"
      end
      w.vm.provision :shell, inline: "iptables -P FORWARD ACCEPT"
      w.vm.provision :shell, path: "scripts/install-node.sh"
    end
  end
end
