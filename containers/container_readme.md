# Containers
## Full Documentation
For full instructions see: https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Docker/

## Podman
These containers were designed under the podman runtime, and are fully compatible with being run as rootless.

If you are familiar with container infrastructure, you can simply copy this entire directory and modify the compose.yaml
to fit your needs.

## Quick Instructions

For podman:
```shell
podman-compose up
```

or if you use non-free runtime:

```shell
docker-compose up
```

Then refer to other FTS documentation to do appropriate configuration.

All config files you need should be created in the volume, so it is a good idea to create a mounted volume instead of a 
standard volume.

If you are missing any/all configuration files, ensure:
  - Restart container to trigger copy script again
  - Permissions are sufficient for the container to use the volume directory
  - On selinux hosts, sticky bit may need to be set
  - Also on selinux, you may need to reload the labels/contexts
