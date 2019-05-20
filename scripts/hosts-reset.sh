#!/usr/bin/env bash

# 清理自定义配置host

sudo sed -i '/#### LIS-SITES-BEGIN/,/#### LIS-SITES-END/d' /etc/hosts

printf "#### LIS-SITES-BEGIN\n#### LIS-SITES-END" | sudo tee -a /etc/hosts > /dev/null
