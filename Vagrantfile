# -*- mode: ruby -*-
# vi: set ft=ruby :


require 'json'
require File.expand_path(File.dirname(__FILE__) + '/scripts/config.rb')

confDir = File.expand_path(File.dirname(__FILE__))
configPath = confDir + "/config.json"

Vagrant.configure("2") do |config|

    if File.exist? configPath then
        settings = JSON::parse(File.read(configPath))
    else
        abort "config settings file not found in #{confDir}"
    end

    Config.set(config, settings)

    if Vagrant.has_plugin?("vagrant-vbguest")
        config.vbguest.auto_update = false
    end

    if Vagrant.has_plugin?('vagrant-hostmanager')
        config.hostmanager.enabled = true
        config.hostmanager.manage_host = true
        config.hostmanager.aliases = settings['sites'].map { |site| site['map'] }
    end

end
