#!/usr/bin/ruby
# @Author: Lis
# @Date:   2019-05-19 21:14:14

class Config
    def self.set (config, settings)
        # 设置虚拟机类型 默认virtualbox
        ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

        script_dir = File.dirname(__FILE__)

        # 设置虚拟机配置 name 是和虚拟机的关联属性
        config.vm.define settings['name'] ||= 'lis-centos'
        config.vm.box = settings['box'] ||= 'lis/centos'
        config.vm.box_version = settings['version'] ||= '0'
        config.vm.hostname = settings['hostname'] ||= 'lis'

        config.vm.provider 'virtualbox' do |box|
            box.name = settings['name'] ||= 'lis-centos'
            box.customize ['modifyvm', :id, '--memory', settings['memory']  ||= '2048']
            box.customize ['modifyvm', :id, '--cpus', settings['cpus']  ||= '1']
            box.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
            box.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
            box.customize ['modifyvm', :id, '--ostype', 'RedHat_64']
        end


        # 设置ip
        ip = '0.0.0.0'
        if settings['ip'] != 'autonetwork'
            ip = settings['ip'] ||= '192.168.10.10'
            config.vm.network :private_network, ip: ip
        else
            ip = '0.0.0.0'
            config.vm.network :private_network, ip: ip, auto_network: true
        end

        # 共享文件夹
        config.vm.synced_folder ".", "/vagrant", disabled: true
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

        unless settings.has_key?('default_ports') && settings['default_ports'] == false
            default_ports.each do |guest, host|
                unless settings['ports'].any? { |mapping| mapping['guest'] == guest }
                    config.vm.network 'forwarded_port', guest: guest, host: host, auto_correct: true
                end
            end
        end

        if settings.has_key?('ports')
            settings['ports'].each do |port|
                config.vm.network 'forwarded_port', guest: port['guest'], host: port['host'], protocol: port['protocol'], auto_correct: true
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
                type = site['type'] ||= 'laravel'
                http_port = '80'

                config.vm.provision 'shell' do |s|
                    s.name = 'Creating site: ' + site['map']
                    s.path = script_dir + "/serve-#{type}.sh"
                    s.args = [site['map'], site['to'], site['port'] ||= http_port]
                end

                config.vm.provision 'shell' do |s|
                   s.name = 'Setting hosts'
                   s.path = script_dir + '/hosts-add.sh'
                   s.args = ['127.0.0.1', site['map']]
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


        # 备份数据库
        if settings.has_key?('backup') && settings['backup']
          dir = settings['backup_dir'] ||= "/var/www/backup"
          settings['databases'].each do |database|
            Config.backup_postgres(database, dir, config)
          end
        end

        # 重启服务
        config.vm.provision 'shell' do |s|
            s.name = 'Restarting Nginx php-fpm'
            s.inline = 'sudo systemctl reload nginx; sudo systemctl restart php-fpm;'
        end

    end

    def self.backup_postgres(database, dir, config)
      now = Time.now.strftime("%Y%m%d%H%M")
      config.trigger.after :provision do |trigger|
        trigger.warn = "Backing up postgres database #{database}..."
        trigger.run_remote = { inline: "mkdir -p #{dir} && pg_dump -U postgres -f #{dir}/#{database}-#{now}.sql #{database}" }
      end
    end
end
