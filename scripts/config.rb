#!/usr/bin/ruby
# @Author: Lis
# @Date:   2019-05-19 21:14:14

class Config
    def self.set (config, settings)
        # 设置虚拟机类型 默认virtualbox
        ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

        script_dir = File.dirname(__FILE__)

        # 运行ssh代理转发
        config.ssh.insert_key = false
        config.ssh.forward_agent = true
        config.ssh.username = settings['username'] ||= 'vagrant'
        config.ssh.password = settings['password'] ||= 'vagrant'

        # 设置虚拟机配置 name 是和虚拟机的关联属性
        config.vm.define settings['name'] ||= 'lis-centos'
        config.vm.box = settings['box'] ||= 'lis/centos'
        config.vm.box_version = settings['version'] || '>=0.0.1'
        config.vm.hostname = 'lis'

        config.vm.provider 'virtualbox' do |box|
            box.name = settings['name'] ||= 'lis-centos'
            box.customize ['modifyvm', :id, '--memory', settings['memory']  ||= '2048']
            box.customize ['modifyvm', :id, '--cpus', settings['cpus']  ||= '1']
            box.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
            box.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
            box.customize ['modifyvm', :id, '--ostype', 'RedHat_64']
            if settings.has_key?('gui') && settings['gui']
                box.gui = true
            end
        end

        if Vagrant.has_plugin?("vagrant-vbguest")
            config.vbguest.auto_update = false
        end

        # 设置ip
        if settings['ip'] != 'autonetwork'
            config.vm.network :private_network, ip: settings['ip'] ||= '192.168.10.10'
        else
            config.vm.network :private_network, ip: '0.0.0.0', auto_network: true
        end

        # 端口
        if settings.has_key?('ports')
            settings['ports'].each do |port|
                port['guest'] ||= port['to']
                port['host'] ||= port['send']
                port['protocol'] ||= 'tcp'
            end
        else
            settings['ports'] = []
        end

        # Default Port Forwarding
        default_ports = {
            80 => 8000,
            443 => 44300,
            3306 => 33060,
            6379 => 63790,
            5432 => 54320
        }

        # Use Default Port Forwarding Unless Overridden
        unless settings.has_key?('default_ports') && settings['default_ports'] == false
            default_ports.each do |guest, host|
                unless settings['ports'].any? { |mapping| mapping['guest'] == guest }
                    config.vm.network 'forwarded_port', guest: guest, host: host, auto_correct: true
                end
            end
        end

        # Add Custom Ports From Configuration
        if settings.has_key?('ports')
            settings['ports'].each do |port|
                config.vm.network 'forwarded_port', guest: port['guest'], host: port['host'], protocol: port['protocol'], auto_correct: true
            end
        end

        # Configure The Public Key For SSH Access
        # if settings.include? 'authorize'
        #     if File.exist? File.expand_path(settings['authorize'])
        #         config.vm.provision 'shell' do |s|
        #             s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys"
        #             s.args = [File.read(File.expand_path(settings['authorize']))]
        #         end
        #     end
        # end

        # Copy The SSH Private Keys To The Box
        if settings.include? 'keys'
            if settings['keys'].to_s.length.zero?
                puts 'Check your Homestead.yaml file, you have no private key(s) specified.'
                exit
            end
            settings['keys'].each do |key|
                if File.exist? File.expand_path(key)
                    config.vm.provision 'shell' do |s|
                        s.privileged = false
                        s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
                        s.args = [File.read(File.expand_path(key)), key.split('/').last]
                    end
                else
                    puts 'Check your Homestead.yaml (or Homestead.json) file, the path to your private key does not exist.'
                    exit
                end
            end
        end


        # 共享文件夹
        config.vm.synced_folder ".", "/vagrant", disabled:true
        if settings.include? 'folders'
            settings['folders'].each do |folder|
                if File.exist? File.expand_path(folder['map'])
                    mount_opts = []

                    if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'hyperv'
                        folder['type'] = 'smb'
                    end

                    if folder['type'] == 'nfs'
                        mount_opts = folder['mount_options'] ? folder['mount_options'] : ['actimeo=1', 'nolock']
                    elsif folder['type'] == 'smb'
                        mount_opts = folder['mount_options'] ? folder['mount_options'] : ['vers=3.02', 'mfsymlinks']

                        smb_creds = {'smb_host': folder['smb_host'], 'smb_username': folder['smb_username'], 'smb_password': folder['smb_password']}
                    end

                    # For b/w compatibility keep separate 'mount_opts', but merge with options
                    options = (folder['options'] || {}).merge({ mount_options: mount_opts }).merge(smb_creds || {})

                    # Double-splat (**) operator only works with symbol keys, so convert
                    options.keys.each{|k| options[k.to_sym] = options.delete(k) }

                    config.vm.synced_folder folder['map'], folder['to'], type: folder['type'] ||= nil, **options

                    # Bindfs support to fix shared folder (NFS) permission issue on Mac
                    if folder['type'] == 'nfs' && Vagrant.has_plugin?('vagrant-bindfs')
                        config.bindfs.bind_folder folder['to'], folder['to']
                    end
                else
                    config.vm.provision 'shell' do |s|
                        s.inline = ">&2 echo \"Unable to mount one of your folders. Please check your folders in config.json\""
                    end
                end
            end
        end

        # 配置域名网站
        config.vm.provision 'shell' do |s|
          s.path = script_dir + '/clear-nginx.sh'
        end

        config.vm.provision 'shell' do |s|
          s.path = script_dir + '/hosts-reset.sh'
        end

        if settings.include? 'sites'
            settings['sites'].each do |site|
                # config.vm.provision 'shell' do |s|
                #     s.name = 'Creating Certificate: ' + site['map']
                #     s.path = script_dir + '/create-certificate.sh'
                #     s.args = [site['map']]
                # end

                type = site['type'] ||= 'laravel'
                http_port = '80'
                https_port = '443'

                config.vm.provision 'shell' do |s|
                    s.name = 'Creating site: ' + site['map']
                    if site.include? 'params'
                        params = '('
                            site['params'].each do |param|
                                params += ' [' + param['key'] + ']=' + param['value']
                            end
                        params += ' )'
                    end
                    if site.include? 'headers'
                        headers = '('
                            site['headers'].each do |header|
                                headers += ' [' + header['key'] + ']=' + header['value']
                            end
                        headers += ' )'
                    end
                    if site.include? 'rewrites'
                        rewrites = '('
                            site['rewrites'].each do |rewrite|
                                rewrites += ' [' + rewrite['map'] + ']=' + "'" + rewrite['to'] + "'"
                            end
                        rewrites += ' )'
                        # Escape variables for bash
                        rewrites.gsub! '$', '\$'
                    end

                    s.path = script_dir + "/serve-#{type}.sh"
                    s.args = [site['map'], site['to'], site['port'] ||= http_port, site['ssl'] ||= https_port, site['php'] ||= '7.3', params ||= '', site['xhgui'] ||= '', site['exec'] ||= 'false', headers ||= '', rewrites ||= '']
                end

                # 定时任务
                if site.has_key?('schedule')
                    config.vm.provision 'shell' do |s|
                        s.name = 'Creating Schedule'

                        if site['schedule']
                            s.path = script_dir + '/cron-schedule.sh'
                            s.args = [site['map'].tr('^A-Za-z0-9', ''), site['to']]
                        else
                            s.inline = "rm -f /etc/cron.d/$1"
                            s.args = [site['map'].tr('^A-Za-z0-9', '')]
                        end
                    end
                else
                    config.vm.provision 'shell' do |s|
                        s.name = 'Checking for old Schedule'
                        s.inline = "rm -f /etc/cron.d/$1"
                        s.args = [site['map'].tr('^A-Za-z0-9', '')]
                    end
                end

            end
        end

        # 重启服务
        config.vm.provision 'shell' do |s|
            s.name = 'Restarting Nginx'
            s.inline = 'sudo systemctl reload nginx; sudo systemctl restart php-fpm;'
        end

    end
end
