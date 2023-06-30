# Notifier

This is the notifier app for the NGINX Microservices March demo architecture.

## Responsibility

This service listens for notifications of events in the system that might need a notification sent to a user. It then dispatches notifications based on the user's notification preferences.

## Requirements

This project requires either `NodeJS` or `Docker` to run. Using `NodeJS` will recreate a local development environment. Using `Docker` will let you recreate a pseudo production environment.

### NodeJS

This project uses `NodeJS`. The current version is specified in [`.tool-versions`](https://github.com/microservices-march/notifier/blob/main/.tool-versions). `NodeJS` is a rapidly evolving language which makes it critical to explicitly define which version is being used to avoid any potential errors due to mismatched versions.

We recommended that you use [asdf](https://asdf-vm.com/guide/getting-started.html) to manage your local `NodeJS` installation. Once you have `asdf` installed, you can run `asdf install` to automatically install the version of `NodeJS` specified in [`.tool-versions`](https://github.com/microservices-march/notifier/blob/main/.tool-versions).

<details>
<summary>

#### Why `asdf`?
</summary>
In a microservices environment, you may have to work on projects that use different versions of a runtime like `NodeJS`, or use a different language altogether!

[asdf](https://asdf-vm.com/guide/getting-started.html) is a single tool that lets you manage multiple versions of different languages in isolation and will automatically install and/or switch to the required runtime/version in any directory that has a `.tool-versions` file.

This is helpful in getting closer to [dev/prod parity](https://12factor.net/dev-prod-parity) in a microservices environment. As you can see in this project, the [GitHub action workflow](https://github.com/microservices-march/notifier/blob/main/.github/workflows/test.yml) uses the same version called out in [`.tool-versions`](https://github.com/microservices-march/notifier/blob/main/.tool-versions) to test the codebase and build a Docker image.

This way, if we use `asdf` we're guaranteed to be developing, testing, and releasing to a consistent version of NodeJS.
</details>

You can also install `NodeJS` by other means - just reference the version number in the `.tool-versions` file.

### Docker

You can run this project on a container using `Docker` together with `Docker Compose`. This will let you build a simple reproducible image and forget about setting up your local environment. Instructions on how to install `Docker` can be found in the [`Docker` website](https://docs.docker.com/get-docker/). (`Docker Compose` is included as part of the recommended `Docker` installation instructions.)

## Setup

**Note:** Instructions marked as (NodeJS - Dev) are only necessary if you want to recreate a local development environment. Instructions marked as (Docker - Prod) are only necessary if you want to recreate a pseudo production environment (careful, it's not actually production ready!).

1. Clone this repo:

    ```bash
    git clone https://github.com/microservices-march/notifier
    ```

2. Start the `notifier` service PostgreSQL database:

    ```bash
    docker-compose up -d
    ```

3. (Docker - Prod) From the root directory of this repository, build the `notifier` Docker image:

    ```bash
    # in ./app
    docker build -t notifier .
    ```

4. (Docker - Prod) Start the `notifier` service in a container:

    ```bash
    docker run -d -p 5000:5000 --name notifier -e PGPASSWORD=postgres -e CREATE_DB_NAME=notifier -e PGHOST=notifier-db-1 -e AMQPHOST=rabbitmq -e AMQPPORT=5672 -e PORT=5000 -e PGPORT=5433 --network mm_2023 notifier

    ```

5. (Docker - Prod) SSH into the container to set up the PostgreSQL DB:

    ```bash
    docker exec -it messenger /bin/bash
    ```

6. (NodeJS - Dev) Install NodeJS modules:

    ```bash
    # in ./app
    npm install
    ```

7. Create the PostgreSQL DB:

    ```bash
    # in ./app
    PGDATABASE=postgres node scripts/create-db.mjs
    ```

8. Create the PostgreSQL DB tables:

    ```bash
    # in ./app
    node scripts/create-schema.mjs
    ```

9. Create some PostgreSQL DB seed data:

    ```bash
    # in ./app
    node scripts/create-seed-data.mjs
    ```

10. (NodeJS - Dev) Start the service:

    ```bash
    # in ./app
    node index.mjs
    ```

## Using the Service

There is no configuration needed to run this service. When properly configured together with the [messenger service](https://github.com/microservices-march/messenger), if a new message is sent via that service, you should see log entries in this service detailing any messages that have been sent.

## Application Notes

The configuration data for this application can be seen in the [configuration schema](https://github.com/microservices-march/notifier/blob/main/config/config.mjs).

This application serves as a simple example of a service handling events from a message queue and having its own database. However, it intentionally does not do a few things for the sake of simplicity:

* Notifications are not actually sent
* A log of sent notifications is not kept in a queryable way - however it is possible to reference the logs to see dispatch

### A Note on Code and Style

The code for this example is written in a style that not in line with application development best practices.

Instead, it is optimized to be quickly understood by those seeking to understand the Microservices March Demo Architecture without assuming special familiarity with:

* Javascript
* NodeJS
* Express

Therefore, we've opted to:

* Avoid frameworks that have domain specific languages (ie, database libraries)
* Avoid splitting up code into many different files

## Cleanup

If you want to cleanup any artifacts resulting from running this project, run:

* If you used `NodeJS` to run the project:

  ```bash
  rm -rf node_modules
  ```

* If you used `Docker` to run the project:

  ```bash
  docker rmi notifier
  ```

## Development

Read the [`CONTRIBUTING.md`](https://github.com/microservices-march/notifier/blob/main/CONTRIBUTING.md) file for instructions on how to best contribute to this repository.

## License

[Apache License, Version 2.0](https://github.com/microservices-march/notifier/blob/main/LICENSE)

&copy; [F5 Networks, Inc.](https://www.f5.com/) 2023
