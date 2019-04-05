# docker-centos-xfce-ja
Dockerfile for Xfce on CentOS. You can use noVNC for remote access.

## Building Docker image
```
cd docker-centos-xfce-ja
docker build -t <image_name>[:tag] .
```

## Running Docker container
```
docker run -d -h <host_name> -p 5901:5901 -p 6901:6901 --privileged <image_name>[:tag] /sbin/init
```

If ```-p <port>:22``` is set, you can login the container using SSH port forwarding.
```
ssh -p <port> foo@localhost
```

If ```-e DISPLAY=host.docker.internal:0``` is set, you can use X11 forwarding.
```
ssh -p <port> -X foo@localhost
```

## Connecting Docker container using noVNC
Start the browser and access to ```https://localhost:6901```.

## Connecting Docker container using Docker CLI
```
docker exec -it <container_id> /bin/bash
```
