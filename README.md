### vagrantfile

#### 前置条件

- 安装[VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- 安装[vagrant](https://www.vagrantup.com/downloads.html)
- 安装[git客户端](https://git-scm.com/downloads)

#### 安装开发环境

- 下载并解压(不能是中文目录)最新版本脚本 [https://github.com/lisxp/vagrantfile](https://github.com/lisxp/vagrantfile/releases)
- 进入目录 `vagrantfile` 右键打开 `Git Bash`
- `cp config.json.example config.json`
- 编辑`config.json`
    - `folders` 共享文件夹，本机映射到虚拟机
    - `sites` 配置域名
- 本机`hosts`添加一行 `192.168.10.10 test.box`(config.json里面配置的域名)

---
##### --> 在线安装
- `vagrant box add lis/centos`

##### --> 离线安装
- 将`lis-centos.box`文件复制到当前目录 [下载链接][1]
- `vagrant box add lis/centos lis-centos.box`

---

- `vagrant up`
- 浏览器访问`IP 192.168.10.10`或域名`test.box`



---

#### 预装应用

- `PHP 7.3.5`
- `nginx 1.16.0`
- `git 2.22.0`
- `node 10.15.3`
- `npm 6.4.1`
- `composer v.8.5`
- `redis-cli 3.2.12`

[1]: https://vagrantcloud.com/lis/boxes/centos/versions/0.0.2/providers/virtualbox.box
