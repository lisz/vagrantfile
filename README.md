### vagrantfile

#### 前置条件

- 安装[VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- 安装[vagrant](https://www.vagrantup.com/downloads.html)
- 安装[git客户端](https://git-scm.com/downloads)

#### 安装开发环境

- 下载并解压最新版本脚本 [https://github.com/lisxp/vagrantfile](https://github.com/lisxp/vagrantfile/releases)
- 进入目录 `vagrantfile` 右键打开 `Git Bash`
- `cp config.json.example config.json`
- 编辑`config.json`
    - `authorize` 登录认证`key` 可忽略直接删除
    - `keys` git 仓库的`ssh`秘钥，用`http https`连接可忽略直接删除
    - `folders` 共享文件夹，本机映射到虚拟机
    - `sites` 配置域名
- 本机`hosts`添加一行 `192.168.10.10 test.box`(config.json里面配置的域名)

---
##### 在线安装
- `vagrant box add lis/centos`

##### 离线安装
- 将`lis-centos.box`文件复制到当前目录
- `vagrant box add metadata.json`

---

- `vagrant up`
- 访问域名`test.box`



