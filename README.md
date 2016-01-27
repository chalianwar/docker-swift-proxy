#Docker OpenStack Swift Proxy Server

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

Over here, we mapped 8080 port of container to port 12345 on host. 


We specified three nodes to be added as object servers. Please note that two of these containers are runing
on same machine (192.168.0.153). We separate them based on the object, account, and container port mapping
from container to host, i.e., one container maps 6010:6010, 6011:6011, 6012:6012 whereas other
container used 5010:6010, 5011:6011, and 5012:6012. Also note that we mentioned only one port and next
two are calculated automatically by adding 1 and 2. 


Similarly, storage device that container
can use for storing the data in case of each container is also specified. Please, be sure you specify
the correct device which has enough disk space. Using incorrect device can be catastrophic.


SWIFT_PWORKERS is used to set the proxy workers dynamically.

The ring files created at the proxy server needs to be copied to the object servers as well. SWIFT_SCP_COPY
contains the remote location path where ring files can be copied to so that we
can copy these files before launching object, container, and account servers on object servers. root@192.168.0.171:~/files is the remote path, whereas kevin is the `scp password`.

At this point OpenStack Swift proxy is running.


```bash
hulk0@host1:~$ docker ps
CONTAINER ID        IMAGE                                     COMMAND                CREATED             STATUS              PORTS                     NAMES
f7bd815a49ee        alivt/swift-proxy   "/bin/sh -c /usr/loc   4 seconds ago       Up 2 seconds        0.0.0.0:12345->8080/tcp   kickass_bohr
```

Next, we need to launch object server containers on the machines we specified. To launch object servers please look at the following:
https://github.com/chalianwar/docker-swift-object


Once object server containers are up and running, we can use the swift python client to access Swift using the Docker forwarded port, in this example port 12345.

```bash
hulk0@host1:~$ swift -A http://127.0.0.1:12345/auth/v1.0 -U test:tester -K testing stat
       Account: AUTH_test
    Containers: 0
       Objects: 0
         Bytes: 0
 Accept-Ranges: bytes
    Connection: keep-alive
   X-Timestamp: 1450494080.48790
    X-Trans-Id: tx8a5e8267911a4ac99f01c-0056a89c11
  Content-Type: text/plain; charset=utf-8
```

Try uploading a file:

```bash
hulk0@host1:~$ swift -A http://127.0.0.1:12345/auth/v1.0 -U test:tester -K testing upload swift swift.txt
swift.txt
```

That's it!
