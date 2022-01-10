# Подготовка пользователей kubernetes

## Описание

Для предоставления доступа пользователю к кластеру kubernetes обычно необходимо проделать несколько довольно трудоёмких шагов:
- генерация ключа
- создание запроса на сертификат ( CSR - Certificate Signing Request) на основе созданого ключа и заранее подготовленной конфигурации
- загрузка CSR в kubernetes
- генерация сертификата на основе CSR средствами kubernetes
- создание конфигурационного файла пользователя, содержащего ключ и подписаный сертификат

Причём первые два шага в идеале должен выполнить пользователь. Конечно научить каждого пользователя выполнять эти процедуры непросто

Данный скрипт автоматизирует все эти действия. В результате работы будет создана одноимённая пользователю директория с артифактами. 

Далее необходимо передать пользователю файл `${USERNAME}/config`, который тот должен сохранить в `~/.kube/config`


## Использование

Сначала необходимо задать имя и адрес кластера в файле `cluster.env`. После этого можно запускать скрипт `prepare_user.sh`

В качестве параметров задаём имя пользователя и отдел в которм он работает. Так же если уже есть ключ, его можно передать третьим параметром:

```bash 
./prepare_user.sh $USER_NAME $USER_DEPARTAMENT [$KEY_PATH]
```

Пример:

```bash 
./prepare_user.sh geytsbills management


KEY_PATH not set. Generating new user key...
Generating RSA private key, 2048 bit long modulus (2 primes)
............................................................................+++++
...........+++++
e is 65537 (0x010001)

Generating CSR...

Apply csr yaml manifest to kubernetes...
certificatesigningrequest.certificates.k8s.io/geytsbills_csr created

Kubernetes CSR status: 
geytsbills_csr   2s    kubernetes.io/kube-apiserver-client   kubernetes-admin   <none>              Pending
Sign..
certificatesigningrequest.certificates.k8s.io/geytsbills_csr approved

Kubernetes CSR status: 
geytsbills_csr   14s   kubernetes.io/kube-apiserver-client   kubernetes-admin   <none>              Approved,Issued

Generating user config...
OK!
```

```bash
ls -la geytsbills/


total 32
drwxr-xr-x 2 akudryashov Users 4096 Jan 10 07:33 .
drwxr-xr-x 8 akudryashov Users 4096 Jan 10 07:30 ..
-rw-r--r-- 1 akudryashov Users 5799 Jan 10 07:33 config
-rw-r--r-- 1 akudryashov Users 1127 Jan 10 07:32 geytsbills.csr
-rw------- 1 akudryashov Users 1675 Jan 10 07:30 geytsbills.key
-rw-r--r-- 1 akudryashov Users  412 Jan 10 07:32 geytsbills_csr.cnf
-rw-r--r-- 1 akudryashov Users 1833 Jan 10 07:32 geytsbills_csr.yaml
```


## Требования
Для работы скрипта необходимо установить следующие пакеты:
- openssl - криптографическая библиотека
- j2cli ( https://github.com/kolypto/j2cli ) - консольный Jinja2 шаблонизатор
- kubectl - утилита для работы с kubernetes

## (C) Andrey Kudryashov
