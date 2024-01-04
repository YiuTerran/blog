---
title: Ansible速成
description:
toc: true
authors: ["tryao"]
tags: ["devops", "ansible"]
categories: []
series: []
date: 2024-01-04T14:00:55+08:00
lastmod: 2024-01-04T14:00:55+08:00
featuredVideo:
featuredImage:
draft: false
---

虽然iac(infracture as code)流行以来，新的技术栈层出不穷，但是一般都是面向k8s或者云服务商的。传统的部署还是用ansible这种仅依赖ssh的最简单。

数年前我还在主力写Python时，部署工具一般使用Python的一个库，叫`fabric`的来进行，它底层就是使用ssh远程登录运行命令而已。`ansible`其实是同样的原理，只不过它的抽象程度更高，可以通过配置文件来驱动，而不再是Python代码。这个配置文件就是所谓的`playbook`，也是yaml格式。

## Inventory文件

即需要配置的主机、环境变量相关的配置文件，支持`ini`或者`yaml`格式，这里统一用`yaml`格式（因为其他配置也是yaml）。

### 语法

例子：

```yaml
ungrouped:
  hosts:
    mail.example.com:
webservers:
  hosts:
    foo.example.com:
    bar.example.com:
dbservers:
  hosts:
    one.example.com:
    two.example.com:
    three.example.com:
east:
  hosts:
    foo.example.com:
    one.example.com:
    two.example.com:
west:
  hosts:
    bar.example.com:
    three.example.com:
prod:
  children:
    east:
test:
  children:
    west:
```

top key是组的名称，可以通过`children`配置父子组。

host可以属于多个group，一个group也可以有复数个parent或者children。

多个类似的host或者ip地址，可以用类似`www[01:50].example.com`或者`172.16.1.[1:100]`这种格式，避免写太多。

可以写alias：

```yaml
ungrouped:
  hosts:
     node1:
       ansible_port: 22
       ansible_host: 172.16.11.200
```

除了上面这些字段外，可以给主机增加任意字段，相当于环境变量：

```yaml
ungrouped:
  hosts:
     node1:
       ansible_port: 22
       ansible_host: 172.16.11.200
       ansible_user: user
       ansible_password: 明文密码
       ansible_ssh_private_key_file: 私钥文件
       ansible_become_user: root #切换成高权限用户
       ansible_become_password: 高权限用户密码
       ansible_python_interpreter: # 远程python解释器地址
       foo: bar
```

一组host也可以共享变量，使用`vars`：

```yaml
ungrouped:
  hosts:
     node1:
       ansible_port: 22
       ansible_host: 172.16.11.200
       foo: bar
  vars:
    k: v
```

子分组亦然。

如果变量太多，可以单独存放在独立的文件里。如`group_vars/group1.yml`，注意这里就仅支持yaml了。文件里面就是普通的yaml，如：

```yaml
---
foo: bar
```

除了`group_vars`，也可以有`host_vars`文件夹。

默认会生成`all`这个组，一个实例如下：

```bash
deploy:
  hosts:
    node1:
      ansible_host: 172.16.11.200
      ansible_port: 22
      ansible_user: root
    node2:
      ansible_host: 172.16.11.125
      ansible_port: 22
      ansible_user: lab-dev
    node3:
      ansible_host: 172.16.11.126
      ansible_port: 22
      ansible_user: ubuntu
```

默认使用ssh私钥连接，有多个私钥的话需要在配置里面手动指定。

```bash
ansible all -m ping -i env/hosts.yml
```

这个命令用来检测所有host的连通性，适合用来测试。

`all`在这里可以替换`deploy`，此外如果有多个组，可以用`deploy:&staging`这种集合计算方式，或者用`172.16.1.*`这种通配符；用`:`做分隔符。

### 文件组织

可以直接使用`-i`传入多个配置文件，也可以直接传入一个配置文件夹。

合并同名变量的逻辑是后导入的覆盖先导入的，对于文件夹而言，就是文件名的ASCII顺序。

```
inventory/
  01-openstack.yml          # configure inventory plugin to get hosts from Openstack cloud
  02-dynamic-inventory.py   # add additional hosts with dynamic inventory script
  03-static-inventory       # add static hosts
  group_vars/
    all.yml                 # assign variables to all hosts
```

上面是一个文件夹的例子，在文件名前使用数字可以有效确定导入顺序。

使用方法：`ansible-playbook playbook.yml -i inventory`

如果不指定`-i`，则默认使用`/etc/ansible/hosts`配置。

### 动态host

云服务厂商那边，可能使用动态的主机规划（虚拟机级别的自动扩容），此时可以考虑使用动态host.

## Playbook

即要做的事情，一般的bash脚本都可以转成playbook，或者直接使用`shell`命令调用已经写好的bash脚本。

### 语法

一个`playbook`对应一个yaml文件，里面含有若干个`play`。`play`是剧本的意思，里面可以含有若干个`task`，`task`里面再调用具体的`module`来执行命令。例如：

```yaml
---
- hosts: webservers
  vars:
    http_port: 80
    max_clients: 200
  remote_user: root
  tasks:
  - name: ensure apache is at the latest version
    yum: pkg=httpd state=latest
  - name: write the apache config file
    template: src=/srv/httpd.j2 dest=/etc/httpd.conf
    notify:
    - restart apache
  - name: ensure apache is running
    service: name=httpd state=started
  handlers:
    - name: restart apache
      service: name=httpd state=restarted
```

上面是一个`play`的例子。`hosts`这里对应`inventory`里面的分组。

`template`命令用来将`jinja2`模板渲染成配置文件，渲染的时候会携带上下文变量。

`notify`用于触发事件，在`handler`那边处理。一般用来重启服务，方便复用。

module除了`=`参数外，一般也支持用yaml的object来写。

一般写playbook就是组合各种module，用来替换传统的bash.

### 文件组织

如果我们希望在多个playbook中复用同一系列task，可以将task单独提取到文件里，如：

```yaml
---
# possibly saved as tasks/foo.yml

- name: placeholder foo
  command: /bin/foo

- name: placeholder bar
  command: /bin/bar
```

然后在源文件里使用：

```
tasks:
  - include: tasks/foo.yml
    vars:
      k: v
      k2: [v2]
```

可以传递变量。

更进一步的抽象则使用`roles`的概念，将文件组织如下：

```yml
site.yml
webservers.yml
fooservers.yml
roles/
   common/
     files/
     templates/
     tasks/
     handlers/
     vars/
     defaults/
     meta/
   webservers/
     files/
     templates/
     tasks/
     handlers/
     vars/
     defaults/
     meta/
```

那么playbook可以简化如下：

```yml
---

- hosts: webservers

  pre_tasks:
    - shell: echo 'hello'

  roles:
    - role: webservers
      foo: bar

  tasks:
    - shell: echo 'still busy'

  post_tasks:
    - shell: echo 'goodbye'
```

并约定：

- 如果 roles/x/tasks/main.yml 存在, 其中列出的 tasks 将被添加到 play 中
- 如果 roles/x/handlers/main.yml 存在, 其中列出的 handlers 将被添加到 play 中
- 如果 roles/x/vars/main.yml 存在, 其中列出的 variables 将被添加到 play 中
- 如果 roles/x/meta/main.yml 存在, 其中列出的 “角色依赖” 将被添加到 roles 列表中 (1.3 and later)
- 所有 copy tasks 可以引用 roles/x/files/ 中的文件，不需要指明文件的路径。
- 所有 script tasks 可以引用 roles/x/files/ 中的脚本，不需要指明文件的路径。
- 所有 template tasks 可以引用 roles/x/templates/ 中的文件，不需要指明文件的路径。
- 所有 include tasks 可以引用 roles/x/tasks/ 中的文件，不需要指明文件的路径。

### 角色依赖

```yaml
---
dependencies:
  - { role: common, some_parameter: 3 }
  - { role: apache, port: 80 }
  - { role: postgres, dbname: blarg, other_parameter: 12 }
```

可以在上面的组织结构里的`meta`文件夹下增加main.yml，声明模块依赖其他角色。

### 其他变量

除了声明在yml文件里的变量，在命令行也可以通过`--extra-vars`传递变量，这个变量可以是json格式，或者`k=v`的文本，或者`@some_file.yml`文件。

系统内置的变量包括：`hostvars`, `group_names`, `groups`和`environmen`等等，不要覆盖这些变量。

### 注册变量

将命令的输出注册为变量，可以使用`register`关键字，例子：

```yaml
- name: test play
  hosts: all

  tasks:

      - shell: cat /etc/motd
        register: motd_contents

      - shell: echo "motd contains the word hi"
        when: motd_contents.stdout.find('hi') != -1
```

`motd_contents`即为注册的变量，可以使用`.stdout_lines`进行分割，并使用`with_items`引用每一行：

```yaml
- name: registered variable usage as a with_items list
  hosts: all

  tasks:

      - name: retrieve the list of home directories
        command: ls /home
        register: home_dirs

      - name: add home dirs to the backup spooler
        file: path=/mnt/bkspool/{{ item }} src=/home/{{ item }} state=link
        with_items: home_dirs.stdout_lines
        # same as with_items: home_dirs.stdout.split()
```

### 循环

上面写的`with_items`歧视是循环引用的一种通用方式，除此之外，还支持`with_nested`, `with_dict`, `with_fileglob`以及`with_together`.

## 总结

我们可以看到playbook的高级语法已经相当于一门DSL了，如果只是为了生成yaml，完全可以用kcl这种配置语言来执行循环、条件等逻辑，还更灵活一点。

playbook自带的使用jinja2渲染模板的功能比kcl更加通用，因为后者目前是专门用来渲染yaml的。如果需要渲染nginx或者emqx这种配置文件，还是需要jinja2这种通用模板的支持的。

devops大部分时间都是面向配置编程，目前流行的技术栈实在是有点多，在一个项目里引入太多技术不利于推广和交接，还是需要谨慎。