=== THIS DOCUMENT IS OUTDATED ===

Will be updated soon.

---------------------------------

#Docker OpenStack Swift onlyone

This is a docker file that creates an OpenStack swift proxy image. You can
specify the object nodes' ip, port, and storage device. Furthermore, you can
specify the ip address, path, and password of the machine where you want to scp
the ring files (you can use specify same machine while launching object server
container so that object server container can have updated ring file).


## startmain.sh

This Dockerfile uses supervisord to manage the processes.
Dockerfile we will be starting multiple services in the container, such as
rsyslog, memcached, and the required OpenStack Swift daemons for launching
swift proxy.


## Usage


```bash
hulk0@host1:~$ docker run -d -p 12345:8080 -e SWIFT_OBJECT_NODES="192.168.0.153:6010:sdb1;192.168.0.153:5010:sdd1;192.168.0.154:6010:sdb1" -e SWIFT_PWORKERS=64  -e SWIFT_SCP_COPY=root@192.168.0.171:~/files:kevin -t alivt/swift-proxy
```

Over here, we mapped 8080 port of container to port 12345 on host. We specified
three nodes to be added as object servers. Please note that two of these containers are runing
on same machine (192.168.0.153). We separate them based on the object, account, and container port mapping
from container to host. One container maps 6010:6010, 6011:6011, 6012:6012 whereas other
container used 5010:6010, 5011:6011, and 5012:6012. Also note that we mentioned only one port and next
two are calculated automatically by adding 1 and 2. Similarly, storage device that container
can use for storing the data in case of each container is also specified. Please, be sure you specify
the correct device which has enough disk space. You can create your own device using following as well.






At this point OpenStack Swift is running.

```bash
vagrant@host1:~$ docker ps
CONTAINER ID        IMAGE                                     COMMAND                CREATED             STATUS              PORTS                     NAMES
4941f8cd8b48        alivt/docker-swift-onlyone:latest   /bin/sh -c /usr/loca   58 seconds ago      Up 57 seconds       0.0.0.0:12345->8080/tcp   hopeful_brattain
```

We can now use the swift python client to access Swift using the Docker forwarded port, in this example port 12345.

```bash
vagrant@host1:~$ swift -A http://127.0.0.1:12345/auth/v1.0 -U test:tester -K testing stat
       Account: AUTH_test
    Containers: 0
       Objects: 0
         Bytes: 0
  Content-Type: text/plain; charset=utf-8
   X-Timestamp: 1402463864.77057
    X-Trans-Id: tx4e7861ebab8244c09dad9-005397e678
X-Put-Timestamp: 1402463864.77057
```

Try uploading a file:

```bash
vagrant@host1:~$ swift -A http://127.0.0.1:12345/auth/v1.0 -U test:tester -K testing upload swift swift.txt
swift.txt
```

That's it!

## Todo

* SELINUX doesn't support btrfs?
* It seems supervisord running as root in the container, a better way to do this?
* bash command to start rsyslog is still running...
* Add all the files in /etc/swift with one ADD command?
* supervisor pid file is getting setup in /etc/
