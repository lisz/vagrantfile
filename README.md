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



---

##### 配置证书登录

- `vagrant ssh`登录到虚拟机(登录密码`vagrant`)
- 生成私钥和公钥`ssh-keygen -t rsa`提示框全部确认
- `cat .ssh/id_rsa.pub .ssh/authorized_keys`
- `mv .ssh/id_rsa /var/www/`复制到本机映射目录
- 配置`config.json`中`private_key_path`，对应`id_rsa`文件位置
- `vagrant reload --privision`



---

#### 预装应用

- `PHP 7.3.5`
- `nginx 1.16.0`
- `git 2.22.0`
- `node 10.15.3`
- `npm 6.4.1`
- `composer v.8.5`
- `redis`