# Containers
## Full Documentation
**WIP**

For full instructions see: https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Docker/overview/

**WIP**

## Podman
These containers were designed under the podman runtime, and are fully compatible with being run as rootless.


## Docker
These containers are likely to work perfectly well in docker.

Please consider running rootless for extra security.

## Quick Instructions
1. Copy the [`example-compose.yaml`](https://github.com/FreeTAKTeam/FreeTAKHub-Installation/blob/main/containers/example-compose.yaml)
file to your favorite directory.
2. Rename it to compose.yaml
3. Run the command

    For podman:
    ```shell
    podman-compose up
    ```
    
    For non-free runtime:
    
    ```shell
    docker-compose up
    ```

4. Then refer to other FTS documentation to do appropriate configuration using the environment variables exposed in the 
compose file.
