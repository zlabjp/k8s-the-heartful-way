# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

require 'openssl'

ROOT_DIR = File.dirname(__FILE__)

CLUSTER_PRIVATE_KEY = ROOT_DIR + "/id_rsa"
CLUSTER_PUBLIC_KEY  = ROOT_DIR + "/id_rsa.pub"
cluster_ssh_private_key = nil
cluster_ssh_public_key = nil

unless File.file?(CLUSTER_PRIVATE_KEY)
  `ssh-keygen -t rsa -N "" -b 4096 -f #{ROOT_DIR}/id_rsa`
end

open(CLUSTER_PRIVATE_KEY) {|io| cluster_ssh_private_key = io.read}
open(CLUSTER_PUBLIC_KEY) {|io| cluster_ssh_public_key = io.read}

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
echo "#{cluster_ssh_public_key}" >> ~vagrant/.ssh/authorized_keys
echo "#{cluster_ssh_private_key}" > ~vagrant/.ssh/id_rsa
echo "#{cluster_ssh_public_key}" > ~root/.ssh/authorized_keys
echo "#{cluster_ssh_private_key}" > ~root/.ssh/id_rsa
chmod 700 ~root/.ssh
chmod 600 ~root/.ssh/id_rsa
EOF

KUBECTL_INSTALLER = <<-EOF
KUBECTL_PATH=/usr/local/bin/kubectl
if [[ ! -f ${KUBECTL_PATH} ]]; then
  curl -L https://storage.googleapis.com/kubernetes-release/release/v1.12.1/bin/linux/amd64/kubectl > ${KUBECTL_PATH}
  chmod +x ${KUBECTL_PATH}
fi
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
      m.vm.provision :shell, inline: KUBECTL_INSTALLER
      m.vm.provision :shell, path: "scripts/gen-certs.sh"
      m.vm.provision :shell, path: "scripts/gen-kubeconfig.sh"
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
      m.vm.provision "docker" do |d|
        d.run "gcr.io/google_containers/hyperkube:v1.12.1",
        auto_assign_name: false,
        daemonize: true,
        cmd: [
          "/hyperkube",
          "apiserver",
          "--authorization-mode=Node,RBAC",
          "--advertise-address=192.168.43.101",
          "--allow-privileged=true",
          "--bind-address=0.0.0.0",
          "--client-ca-file=/etc/kubernetes/secrets/ca.crt",
          "--enable-bootstrap-token-auth=true",
          "--etcd-servers=http://192.168.43.101:2379",
          "--insecure-port=0",
          # "--kubelet-certificate-authority=/etc/kubernetes/secrets/ca.crt",
          # "--kubelet-client-certificate=/etc/kubernetes/secrets/kubelet-client.crt",
          # "--kubelet-client-key=/etc/kubernetes/secrets/kubelet-client.key",
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
          "--volume=/etc/kubernetes:/etc/kubernetes",
          "--volume=/etc/ca-certificates:/etc/ca-certificates",
          "--volume=/usr/share/ca-certificates:/usr/share/ca-certificates",
          "--volume=/usr/local/share/ca-certificates:/usr/local/share/ca-certificates",
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
      w.vm.provision :shell, inline: KUBECTL_INSTALLER
      w.vm.provision "docker", images: ["busybox"]
    end
  end

end
