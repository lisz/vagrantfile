#!/usr/bin/env bash

block="server {
    listen ${3:-80};
    server_name $1;
    root \"$2\";

    charset utf-8;


    access_log off;
    error_log  /etc/nginx/logs/$1-error.log error;
    include php.conf;
}
"

echo "$block" > "/etc/nginx/conf/webroot/$1.conf"
