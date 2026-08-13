# Explanation — Stage 1: Ansible Configuration Management

## Order of execution and reasoning

The playbook (`playbook.yml`) runs five roles in a specific sequence, each depending on the one before it:

1. **`docker`** — Installs and configures Docker Engine, the Compose plugin, and creates the custom bridge network (`yolo-net`) that all application containers will share. This has to run first, since nothing else in the playbook (cloning aside) can function without Docker being present on the target machine.

2. **`app_repo`** — Clones the Yolo application source code (the same repository containing the Dockerfiles from the Week 2 IP) onto the VM. This must run before the backend/frontend roles, since their image builds reference this cloned source directory (`{{ repo_dest }}/backend` and `{{ repo_dest }}/client`).

3. **`mongodb`** — Starts the MongoDB container, attached to the shared Docker network, with a named volume mounted at `/data/db` for persistence. This runs before the backend role because the backend container needs Mongo to already be reachable on the network by the time it starts (the backend's `MONGODB_URI` environment variable references the Mongo container's name directly, relying on Docker's internal DNS on the shared network).

4. **`backend`** — Builds the backend Docker image from the cloned repo's `backend/` folder and runs it, connected to the same network, with its Mongo connection string injected via an environment variable rather than hardcoded.

5. **`frontend`** — Builds and runs the frontend (React + Nginx) container last, since it's the entry point users interact with and has no other services depending on it.

Each role is implemented as a task file under `roles/<role_name>/tasks/main.yml`, and included into the main playbook using `include_role` inside a `block`, with tags matching the role name (`docker`, `repo`, `mongodb`, `backend`, `frontend`). This allows any individual stage to be re-run in isolation for debugging using `ansible-playbook playbook.yml --tags backend`, for example, without re-running the entire pipeline.

## Role responsibilities and Ansible modules used

**`roles/docker`**
- `apt` — installs prerequisite packages and the Docker Engine/CLI/Compose plugin itself.
- `apt_key` / `apt_repository` — registers Docker's official APT repository and its signing key, rather than relying on Ubuntu's often-outdated default Docker packages.
- `service` — ensures the Docker daemon is running and enabled on boot.
- `user` — adds the `vagrant` user to the `docker` group, so subsequent container-management tasks don't require `sudo` for every Docker command.
- `community.docker.docker_network` — creates the shared bridge network (`yolo-net`) used by all three application containers, matching the same networking approach used in the Week 2 Docker Compose setup.

**`roles/app_repo`**
- `git` — clones the application repository to a fixed path (`/home/vagrant/yolo`) on the VM, with `force: true` so re-running the playbook always syncs to the latest commit rather than silently skipping updates.

**`roles/mongodb`**
- `community.docker.docker_container` — runs the `mongo:6.0` image, attaches it to the shared network, and mounts a named volume (`allan-mongo-data`) at MongoDB's data directory. This is the same persistence mechanism proven in the Week 2 Docker Compose setup, now expressed declaratively through Ansible instead.

**`roles/backend`**
- `community.docker.docker_image` — builds the backend image directly from the cloned repository's Dockerfile (`source: build`), rather than pulling a pre-built image, so the image always reflects the current state of the cloned code.
- `community.docker.docker_container` — runs the built image, attaches it to the shared network, and passes `MONGODB_URI` as an environment variable pointing at the Mongo container by name (`mongodb://allan-yolo-mongo:27017/yolomy`), relying on Docker's internal DNS.

**`roles/frontend`**
- Same pattern as the backend role: builds the image from the repo's `client/` Dockerfile, then runs it on the shared network with its port published to the host.

## Variables

All environment-specific and reusable values (repository URL, container names, image tags, ports, network name, volume name) are centralized in `group_vars/all.yml` rather than hardcoded inside individual task files. This means changing an image tag, port, or container name only requires a single edit, and keeps the role logic itself generic and reusable.

## Debugging notes

Two issues came up during development and were resolved:
- The initial playbook run failed intermittently while downloading Docker's GPG key, due to a transient network timeout inside the VM's NAT-networked connection. Re-running the playbook (which is idempotent) resolved this without any configuration change.
- After adding the `vagrant` user to the `docker` group, the very next task briefly reported the host as unreachable — this was due to the SSH session's cached group membership not reflecting the change until a fresh connection was established. Re-running the playbook on a new SSH connection resolved this automatically.
