---
layout: post
title: "Testing with Node and Docker Compose, Part 3: End-to-End"
date: 2020-05-24 12:00:00 +0000
categories: articles
image: /assets/todo-demo/todo-demo-frontend.gif
description: Tutorial article about building and testing node.js applications under Docker and Docker Compose. Part 3 focuses on setting up end-to-end testing.
---

This post is the third in a short series about automated testing in node.js web applications with Docker. So far, we have looked at [backend testing](/articles/2019/10/19/testing-node-docker-compose-backend.html) and [frontend testing](/articles/2020/01/12/testing-node-docker-compose-frontend.html). This post will be about end-to-end testing, which covers both frontend and backend together.

To illustrate, we’ll continue building and testing our example application: a simple TODO list manager, which comprises a RESTful backend and a React frontend:

<p align="center">
  <a href="/assets/todo-demo/todo-demo-frontend.gif"><img src="/assets/todo-demo/todo-demo-frontend.gif" alt="Create some todos and complete them" style="max-width: 448px;"></a>
</p>

In particular, we'll:

- Use Docker Compose `projects` to create separate development and test environments, while sharing some services between the two for efficiency.
- Upgrade our `bin` scripts to manage these separate 'projects'.
- Extract the storage layer from the backend so that the end-to-end tests can use it.
- Set up end-to-end tests with [puppeteer](https://pptr.dev/) in Docker.
- Promote some frontend integration tests using [jsdom](https://github.com/jsdom/jsdom) from the previous post to end-to-end tests, reducing the number of mocks we need to maintain.

As usual, the code is [available on GitHub](https://github.com/jdleesmiller/todo-demo), and each post in the series has a git tag that marks the [corresponding code](https://github.com/jdleesmiller/todo-demo/tree/todo-end-to-end-jsdom/todo).

### Separate Test and Development Environments

The main idea of end-to-end testing is to stand up the whole system, put it into a given state, and then run automatic tests against it. In most cases, this means wiping out the state in the database before each test run, so we'd rather not run them against a development environment used for more manual or exploratory testing. Instead, we'd like to have separate development and test environments.

The simplest approach is to have two completely separate environments, but this can be expensive. For a large application, just running two copies of every service can tax your development machine. And we have to keep these two environments in sync in terms of installed packages and code. Sharing resources between the two environments can help with these problems.

In this case, the shared resources will be the application's postgres server (with separate logical databases for development and test), to save having to run two full postgres instances, and its `node_modules` folders, to keep dependencies in sync between development and test environments. Of course, in a larger application, there might be more that could be shared. In diagram form, what we're aiming for is:

<p align="center">
  <a href="/assets/todo-demo/todo-demo-shared.svg"><img src="/assets/todo-demo/todo-demo-shared.svg" alt="TODO" style="max-width: 448px;"></a>
</p>

Notably:

- The development and test environments each have their own network and on it their own instances of the application's services. This means that development and test services can use the same names in both environments without collisions, which reduces the amount of configuration that has to differ between the environments.

- The postgres database server lives in a third shared environment, with a presence on both development and test networks, so both development and test applications can talk to the same database server (but use different logical databases).

- For faster edit-test cycles, and to keep code in sync between development and test environments, both the development and test services need to have the source code on the host bind mounted in, which means two instances of the '[node modules trick](/articles/2019/09/06/lessons-building-node-app-docker.html)' with a nested `node_modules` volume per service. To keep the dependencies in sync, both the development and test instance of each service mount the same shared `node_modules` volume. That way changes to packages in the development environment are automatically reflected in the test environment.

To set this up, we use several Docker Compose features: project names, variable substitution, Compose file merging, and external links and volumes.

#### Project Names

Compose prepends a [project name](https://docs.docker.com/compose/reference/envvars/#compose_project_name) to all of the resources that it creates in Docker so that they don't conflict with those of other projects. This is why, in the last post, the `backend` and `frontend` services in the Compose file produced containers called `todo_backend_1` and `todo_frontend_1`[^suffix]:
```
$ docker-compose ps
Name                    Command               State           Ports
---------------------------------------------------------------------------------
todo_backend_1    docker-entrypoint.sh npx n ...   Up
todo_frontend_1   docker-entrypoint.sh npx w ...   Up      0.0.0.0:8080->8080/tcp
todo_postgres_1   docker-entrypoint.sh postgres    Up      5432/tcp
```

By default, Compose uses the basename of its working directory, but this can be overridden with the `--project-name` flag. Here we'll use `--project-name todo_development` and `--project-name todo_test` to create two projects for the development and test environments, respectively. We'll also create a third project for the shared environment just called `todo`.

#### Variable Substitutions and Merging Compose Files

Running the same Compose file with different project names lets us create isolated and identical environments, but usually what we actually want is *nearly*-identical environments with small differences. For example, the development and test environments should be as similar as possible, but we need them to use different logical databases. Compose provides two useful features that enable this.

Firstly, for single-value changes, we can use [variable substitution](https://docs.docker.com/compose/compose-file/#variable-substitution) to inject environment variables from the host into the Compose file. Here we'll use an environment variable called `ENV` to control the database name in the database connection string, for example.

Secondly, for larger structural changes to Compose files, the [`--file` flag](https://docs.docker.com/compose/reference/overview/#specifying-multiple-compose-files) lets us load multiple Compose files, which Compose intelligently merges together. Here we'll have a root Compose file with the shared configuration for the development and test environments, and then an environment-specific Compose file for each environment.

#### External Networks, Links and Volumes

To allow Compose to find resources defined in other environments, we'll use the `external` and [`external_links`](https://docs.docker.com/compose/compose-file/#external_links) properties in the Compose file. The development and test projects will refer to [networks](https://docs.docker.com/compose/compose-file/#external-1) and [volumes](https://docs.docker.com/compose/compose-file/#external) in the shared project using `external`, and the services' link to the `postgres` database container is an external link.

Putting this all together, we need three new Compose files and some modifications to our existing Compose file from [part 2](/articles/2020/01/12/testing-node-docker-compose-frontend.html), which we'll take in turn. First, there's the compose file for the shared environment, which sets up the networks, the postgres database, and the `node_modules` volumes.

#### [`docker-compose.shared.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/docker-compose.shared.yml)

```yml
version: '3.7'

networks:
  development_default:
  test_default:

services:
  postgres:
    image: postgres
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
    networks:
      - development_default
      - test_default

volumes:
  backend_node_modules:
  frontend_node_modules:
```

We'll run this `docker-compose.shared.yml` Compose file with the project name set to `todo`, so the `development_default` network here will have the `todo` prefix added, yielding `todo_development_default` as its full name in Docker. The test network will similarly end up being called `todo_test_default`. The shared `postgres` sits on both networks.

The volumes similarly pick up this `todo` prefix and so end up being called `todo_backend_node_modules` and `todo_frontend_node_modules` in Docker.

The main `docker-compose.yml` file then has to change to reference these shared resources, as follows:

#### [`docker-compose.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/docker-compose.yml)

```diff
diff --git a/todo/docker-compose.yml b/todo/docker-compose.yml
index 37983ad..69fbc29 100644
--- a/todo/docker-compose.yml
+++ b/todo/docker-compose.yml
@@ -1,15 +1,22 @@
 version: '3.7'

+# Use the network set up in the shared compose file.
+networks:
+  default:
+    external: true
+    name: todo_${ENV}_default
+
 services:
   backend:
     build:
       context: .
       target: development-backend
     command: npx nodemon server.js
-    depends_on:
-      - postgres
     environment:
+      DATABASE_URL: postgres://postgres:postgres@postgres/${ENV}
       PORT: 8080
+    external_links:
+      - todo_postgres_1:postgres
     volumes:
       - ./backend:/srv/todo/backend
       - backend_node_modules:/srv/todo/backend/node_modules
@@ -24,17 +31,15 @@ services:
     environment:
       HOST: frontend
       PORT: 8080
-    ports:
-      - '8080:8080'
     volumes:
       - ./frontend:/srv/todo/frontend
       - frontend_node_modules:/srv/todo/frontend/node_modules

-  postgres:
-    image: postgres:12
-    environment:
-      POSTGRES_HOST_AUTH_METHOD: trust
-
+# Use the node_modules volumes set up in the shared compose file.
 volumes:
   backend_node_modules:
+    name: todo_backend_node_modules
+    external: true
   frontend_node_modules:
+    name: todo_frontend_node_modules
+    external: true
```

The main changes here are to:

- Redefine the default network as external and point it to the appropriate network from the shared environment. Here we use our `ENV` environment variable, which is set to either `development` or `test`, and Compose variable substitution to switch between the two networks. Our `bin` scripts will handle setting this `ENV` variable, as we'll see shortly.

- Remove the `postgres` service and instead point the `backend` service at the shared postgres service using an external link. The external link has to refer to the full container name, which due to the shared environment's `todo` prefix turns out to be `todo_postgres_1`; however, we alias it to just `postgres` within the current environment, so nothing else needs to know about this. Removing the `postgres` service also means that we have to remove the `backend` service's dependency on it; instead we have to take responsibility for making sure that postgres starts up. The `bin` scripts will again help with this.

- Mark the named `node_modules` volumes as external and point them at the shared volumes.

- Stop exposing port `8080` on the host for the frontend by default. We're going to run the development and test environments at the same time, so they can't both expose the same port.

This brings us to our third and fourth Compose files, which are specific to the development and test environments, and are fortunately very short. The development Compose file lets us expose `8080` for the frontend service only in the development environment:

#### [`docker-compose.development.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/docker-compose.development.yml)

```yml
version: '3.7'

services:
  frontend:
    ports:
      - '8080:8080'
```

The test Compose file doesn't (yet) have anything to add on top of the common configuration from the root `docker-compose.yml`, so it is empty but for its Compose version number:

#### [`docker-compose.test.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/docker-compose.test.yml)

```yml
version: '3.7'
```

### The `bin` Scripts

At this point you may be thinking that it would be a pain to list out all these Compose files and environment variables on the command line, and you would be right. It's no longer practical to run `docker-compose` directly --- instead we will run it only through helper scripts.

The first of these scripts is `bin/dc`, which wraps the `docker-compose` command so it takes as its first argument the environment we want it to run in:

#### [`bin/dc`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/dc)

```bash
#!/usr/bin/env bash

#
# Run docker-compose in the given environment.
#
# Usage: bin/dc <d[evelopment]|t[est]|s[shared]> <arguments for docker-compose>
#

source "${BASH_SOURCE%/*}/.helpers.sh"

docker_compose_in_env "$@"
```

It supports abbreviations, so `bin/dc d ps` or `bin/dc development ps` will both run `docker-compose ps` in the development environment.

The lynchpin of the whole approach is the `docker_compose_in_env` function, which is defined in helper file so other `bin` scripts can use it, so let's look at that:

#### [`bin/.helpers.sh`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/.helpers.sh)

```bash
set -e

# Run docker-compose in the given environment.
function docker_compose_in_env {
  local ENV=$(get_full_env_name $1)
  case $ENV in
  development | test )
    ENV=$ENV docker-compose \
      --project-name todo_$ENV \
      --file docker-compose.yml \
      --file docker-compose.$ENV.yml \
      "${@:2}"
    ;;
  shared )
    docker-compose \
      --project-name todo \
      --file docker-compose.shared.yml "${@:2}" ;;
  * ) echo "Unexpected environment name"; exit 1 ;;
  esac
}

# Get the full environment name, allowing shorthand.
function get_full_env_name {
  case $1 in
    d | development ) echo development ;;
    t | test ) echo test ;;
    s | shared ) echo shared ;;
    * ) echo "Expected environment d[evelopment]|t[est]|s[hared]"; exit 1 ;;
  esac
}
```

In the development and test environments, the `docker_compose_in_env` function

1. sets the Compose project name to `todo_development` or `todo_test`,
1. sets the `ENV` variable to either `development` or `test` for Compose to use for variable substitutions, and
1. loads both the root `docker-compose.yml` Compose file and the appropriate environment-specific Compose file.

It then passes the rest of its arguments on to `docker-compose` with a somewhat cryptic `"${@:2}"`, which makes sense when you know that `$@` expands to all arguments, and the `:2` says we should drop the first one, `$1`, which is the environment name.

The shared environment is simpler: it runs `docker-compose` with the project name set to just `todo` [^project-name] and loads the shared Compose file, `docker-compose.shared.yml`.

Another important script that uses the `docker_compose_in_env` function is the `bin/up` script, which is responsible for starting up the environments. It requires the following changes, compared to last time with a single environment:

#### [`bin/up`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/up)

```diff
diff --git a/todo/bin/up b/todo/bin/up
index 3fa0a0e..d4d6d75 100755
--- a/todo/bin/up
+++ b/todo/bin/up
@@ -1,20 +1,20 @@
 #!/usr/bin/env bash

-set -e
+source "${BASH_SOURCE%/*}/.helpers.sh"

-docker-compose up -d postgres
+docker_compose_in_env shared up -d

 WAIT_FOR_PG_ISREADY="while ! pg_isready --quiet; do sleep 1; done;"
-docker-compose exec postgres bash -c "$WAIT_FOR_PG_ISREADY"
+docker_compose_in_env shared exec postgres bash -c "$WAIT_FOR_PG_ISREADY"

 for ENV in development test
 do
   # Create database for this environment if it doesn't already exist.
-  docker-compose exec postgres \
+  docker_compose_in_env shared exec postgres \
     su - postgres -c "psql $ENV -c '' || createdb $ENV"

   # Run migrations in this environment.
-  docker-compose run --rm -e NODE_ENV=$ENV backend npx knex migrate:latest
+  docker_compose_in_env $ENV run --rm backend npx knex migrate:latest
 done

-docker-compose up -d
+docker_compose_in_env development up -d
```

The script essentially does the same things, but it runs the database-related commands in the `shared` environment, and the migrations in the `development` or `test` environment, as appropriate.

Other useful `bin` scripts include [`bin/test`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/test) to run all the tests (now in the test environment), [`bin/stop`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/stop) to stop all the containers, and [`bin/down`](https://github.com/jdleesmiller/todo-demo/blob/todo-envs/todo/bin/down) to tear things down (now optionally preserving the data in the shared environment).

### The End-To-End Test

Now that we have a separate test environment, we're nearly ready to add an end-to-end test into that environment. The final bits of preparation are to separate out the model layer from the backend into its own package, here called `storage`, and then to write an `end-to-end-test` package to contain the end-to-end test and its dependencies.

The reason to extract a `storage` package is that both the `backend` service and the end-to-end test will need to access the database, and that will be easier if we can share the database-related code between them. Our TODO application is actually simple enough that we could test everything using only public interfaces, using a [black box](https://en.wikipedia.org/wiki/Black-box_testing) approach. However, in more complicated applications, end-to-end tests often benefit from a more grey box approach --- at minimum they need to be able to efficiently reset the database state in between tests, and it is helpful to be able to set up more complicated test scenarios by using the model layer directly.

The [full diff](https://github.com/jdleesmiller/todo-demo/commit/89212a42b3760dd01d3d5f78b21ebe78cdf72199) for splitting out the `storage` package is long, but essentially it moves the database dependencies, configuration, migrations and test helpers, and our model class, `Task`, into [the new package](https://github.com/jdleesmiller/todo-demo/blob/todo-storage/todo/storage):

```
$ tree storage
storage
├── index.js
├── knexfile.js
├── migrations
│   └── 20190720190344_create_tasks.js
├── node_modules
├── package-lock.json
├── package.json
├── src
│   ├── knex.js
│   └── task.js
└── test
    └── support
        ├── cleanup.js
        └── knex-hook.js
```

The `backend` service's `package.json` then gains a [local path dependency](https://docs.npmjs.com/files/package.json#local-paths) on the `storage` package, instead of depending on the database packages directly:

#### [`backend/package.json`](https://github.com/jdleesmiller/todo-demo/blob/todo-storage/todo/backend/package.json)

```diff
diff --git a/todo/backend/package.json b/todo/backend/package.json
index 36855a1..40c2363 100644
--- a/todo/backend/package.json
+++ b/todo/backend/package.json
@@ -13,9 +13,7 @@
   "dependencies": {
     "body-parser": "^1.19.0",
     "express": "^4.17.1",
-    "knex": "^0.19.5",
-    "objection": "^1.6.11",
-    "pg": "^7.12.1"
+    "storage": "file:../storage"
   },
   "devDependencies": {
     "mocha": "^6.2.0",
```

The local path dependency lets us update the storage package locally without having to publish it to npm every time, which would be extremely tedious. This approach also requires the usual changes to the [`Dockerfile`](https://github.com/jdleesmiller/todo-demo/blob/todo-storage/todo/Dockerfile) to `npm install` the package and changes to the [`docker-compose.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-storage/todo/docker-compose.yml) file to bind mount the source for the `storage` package into the containers that need it.

Now we can create the [`end-to-end-test`](https://github.com/jdleesmiller/todo-demo/tree/todo-end-to-end-test/todo/end-to-end-test) package that also depends on the `storage` package and declares our other test dependencies, which are here [mocha](https://mochajs.org/) to drive the test and [puppeteer](https://pptr.dev/) to drive the headless browser that will exercise the frontend. Its [`Dockerfile`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-test/todo/end-to-end-test/Dockerfile) requires some [specific setup](https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#running-puppeteer-in-docker) to allow run puppeteer in a container, but it is well documented.

So, finally, here is the end-to-end test:

#### [`end-to-end-test/test/todo.test.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-test/todo/end-to-end-test/test/todo.test.js)

```js
const assert = require('assert')
const puppeteer = require('puppeteer')

const { Task } = require('storage')
const cleanup = require('storage/test/support/cleanup')

const BASE_URL = process.env.BASE_URL

before(async function() {
  global.browser = await puppeteer.launch({
    executablePath: 'google-chrome-unstable',
    headless: process.env.PUPPETEER_HEADLESS !== 'false'
  })
})

after(async function() {
  await global.browser.close()
})

beforeEach(cleanup.database)

describe('TO DO', function() {
  this.timeout(10000)

  beforeEach(async function() {
    await Task.query().insert([{ description: 'foo' }, { description: 'bar' }])
  })

  it('lists, creates and completes tasks', async function() {
    const page = await global.browser.newPage()
    await page.goto(BASE_URL)

    await waitForNumberOfTasksToBe(page, 2)
    let tasks = await page.$$('.todo-task')

    // Complete task foo.
    assert.strictEqual(await getTaskText(tasks[0]), 'foo')
    let complete = await tasks[0].$('button')
    complete.click()
    await waitForNumberOfTasksToBe(page, 1)

    // Create a new task, baz.
    await page.type('.todo-new-task input[type=text]', 'baz')
    await page.click('.todo-new-task button')
    await page.waitForSelector('.todo-task button')
    await waitForNumberOfTasksToBe(page, 2)

    // Complete task baz.
    tasks = await page.$$('.todo-task')
    assert.strictEqual(await getTaskText(tasks[1]), 'baz')
    complete = await tasks[1].$('button')
    complete.click()
    await waitForNumberOfTasksToBe(page, 1)

    // Only bar should remain.
    tasks = await page.$$('.todo-task')
    assert.strictEqual(await getTaskText(tasks[0]), 'bar')
  })
})

async function waitForNumberOfTasksToBe(page, n) {
  await page.waitForFunction(
    `document.querySelectorAll(".todo-task").length == ${n}`
  )
}

async function getTaskText(elementHandle) {
  return elementHandle.$eval('span', node => node.innerText)
}
```

Key points:

- A global puppeteer instance, `global.browser` is shared by all the tests (though here there's only one test).

- The `BASE_URL` environment variable points it at the `frontend` container (in the test environment), which proxies requests from the browser through to the `backend` container, as discussed in the [previous post](/articles/2020/01/12/testing-node-docker-compose-frontend.html).

- Before each test, it uses functionality from the shared `storage` package to first reset the database state, with `cleanup.database`, and then seed the database with two starter `Task`s, `foo` and `bar`.

- The test itself is based mainly on query selectors. For example, `page.$$('.todo-task')` finds all of the elements on the page with the `todo-task` CSS class, which are the list items for the tasks, as per [the frontend](/articles/2020/01/12/testing-node-docker-compose-frontend.html#frontendsrccomponenttaskjs). More on this later.

- The `waitForNumberOfTasksToBe` helper function uses puppeteer's `waitForFunction` primitive to poll until the given number of tasks are on the page. This is the main way in which the test handles the asynchronous loading and rendering of data.

Now, to run the test, we need to tell Compose how to start a container for it. To do this we create a separate Compose file that we'll merge together with the other Compose files using the `--file` flag discussed above:

#### [`docker-compose.end-to-end-test.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-test/todo/docker-compose.end-to-end-test.yml)

```yaml
version: '3.7'

services:
  end-to-end-test:
    build:
      context: .
      dockerfile: end-to-end-test/Dockerfile
    cap_add:
      - SYS_ADMIN # for puppeteer
    command: npm test
    depends_on:
      - frontend
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres/test
      BASE_URL: http://frontend:8080
    volumes:
      - ./end-to-end-test:/srv/todo/end-to-end-test
      - end_to_end_test_node_modules:/srv/todo/end-to-end-test/node_modules
      - ./storage:/srv/todo/storage
      - storage_node_modules:/srv/todo/storage/node_modules

volumes:
  end_to_end_test_node_modules:
  storage_node_modules:
    name: todo_storage_node_modules
    external: true
```

Notably:

- This Compose file defines an `end-to-end-test` 'service' that we'll only ever run as a one-off command, with `docker-compose run` instead of `docker-compose up`.

- The `end-to-end-test` service defined here depends on the `frontend` service, which is defined in the main Compose file. It therefore depends on the `backend` service too, through the `frontend`. Compose will automatically bring up all the application services required for the end-to-end test. It won't automatically bring up the `postgres` service in the shared environment, however, because it's external --- we have to run the `bin/up` script to make it work.

- It sets the test database URL and the base URL where it can find the frontend as environment variables.

- Like other node services, the source is bind mounted into the container, and we again apply the [node modules trick](/articles/2019/09/06/lessons-building-node-app-docker.html).

So, we've again reached a point in this series where we can run `npm test` in a container:
```sh
bin/up
bin/dc t --file docker-compose.end-to-end-test.yml run --rm end-to-end-test
```
This runs `docker-compose` in the `test` environment (`t`) with our extra Compose file and runs the tests in the container. It's a lot to type, so we'll usually run it through the `bin/test` script, which runs all the tests:

#### [`bin/test`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-test/todo/bin/test)

```bash
#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/.helpers.sh"

docker_compose_in_env test run --rm backend npm test "$@"
docker_compose_in_env test run --rm frontend npm test "$@"
docker_compose_in_env test --file docker-compose.end-to-end-test.yml \
  run --rm end-to-end-test
```

The last line runs the end-to-end tests:

```
$ bin/up
...
$ bin/test
...
Starting todo_test_backend_1 ... done
Starting todo_test_frontend_1 ... done

> end-to-end-test@1.0.0 test /srv/todo/end-to-end-test
> mocha --timeout 10000



  TO DO
    ✓ lists, creates and completes tasks (1724ms)


  1 passing (2s)
```

### Revisiting a Frontend Integration Test

In the [previous post](https://jdlm.info/articles/2020/01/12/testing-node-docker-compose-frontend.html#integration-tests) about frontend testing, we had a frontend integration test running with `jsdom` that made fairly heavy use of request mocking to simulate responses from the backend. Now that we have the infrastructure for end-to-end tests, we have the option of just letting the `jsdom` tests talk to the backend, so let's see how that looks.

The main [change required](https://github.com/jdleesmiller/todo-demo/commit/60be4f35e05e6d52acd0ab2df05138a9d5ed26c5) is that the frontend tests (but not the frontend itself) also needs to load the `storage` package and to be able to talk to the database and the backend. We can add the required config to the test environment Compose file that we stubbed out earlier:

#### [`docker-compose.test.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-jsdom/todo/docker-compose.test.yml)

```yaml
version: '3.7'

services:
  frontend:
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres/test
      BASE_URL: http://backend:8080
```

Then we can remove the mocking from the frontend integration test, which makes it much more succinct:

#### [`frontend/test/integration/todo.test.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-end-to-end-jsdom/todo/frontend/test/integration/todo.test.js)

```diff
diff --git a/todo/frontend/test/integration/todo.test.js b/todo/frontend/test/integration/todo.test.js
index bb0d6dd..bd0a56e 100644
--- a/todo/frontend/test/integration/todo.test.js
+++ b/todo/frontend/test/integration/todo.test.js
@@ -1,23 +1,23 @@
+import assert from 'assert'
 import React from 'react'
 import {
-  cleanup,
+  cleanup as cleanupReactTest,
   fireEvent,
   render,
   waitForElement,
   waitForElementToBeRemoved
 } from '@testing-library/react'

-import fetchMock from '../support/fetch-mock'
+import { Task } from 'storage'
+import { database as cleanupDatabase } from 'storage/test/support/cleanup'
+
 import App from '../../src/component/app'

 describe('TO DO App', function() {
-  afterEach(cleanup)
-  afterEach(fetchMock.reset)
+  beforeEach(cleanupDatabase)
+  afterEach(cleanupReactTest)

   it('lists, creates and completes tasks', async function() {
-    // Load empty list.
-    fetchMock.getOnce('path:/api/tasks', { tasks: [] })
-
     const { getByText, getByLabelText } = render(<App />)

     const description = getByLabelText('new task description')
@@ -25,49 +25,24 @@ describe('TO DO App', function() {

     await waitForElementToBeRemoved(() => getByText(/loading/i))

-    // Create 'find keys' task.
-    fetchMock.postOnce('path:/api/tasks', {
-      task: { id: 1, description: 'find keys' }
-    })
-    fetchMock.getOnce('path:/api/tasks', {
-      tasks: [{ id: 1, description: 'find keys' }]
-    })
     fireEvent.change(description, { target: { value: 'find keys' } })
     fireEvent.click(addTask)

     await waitForElement(() => getByText('find keys'))

-    // Create 'buy milk' task.
-    fetchMock.postOnce('path:/api/tasks', {
-      task: { id: 2, description: 'buy milk' }
-    })
-    fetchMock.getOnce('path:/api/tasks', {
-      tasks: [
-        { id: 1, description: 'find keys' },
-        { id: 2, description: 'buy milk' }
-      ]
-    })
     fireEvent.change(description, { target: { value: 'buy milk' } })
     fireEvent.click(addTask)

     await waitForElement(() => getByText('buy milk'))

-    // Complete 'buy milk' task.
-    fetchMock.deleteOnce('path:/api/tasks/2', 204)
-    fetchMock.getOnce('path:/api/tasks', {
-      tasks: [{ id: 1, description: 'find keys' }]
-    })
-
     fireEvent.click(getByLabelText('mark buy milk complete'))

     await waitForElementToBeRemoved(() => getByText('buy milk'))

-    // Complete 'find keys' task.
-    fetchMock.deleteOnce('path:/api/tasks/1', 204)
-    fetchMock.getOnce('path:/api/tasks', { tasks: [] })
-
     fireEvent.click(getByLabelText('mark find keys complete'))

     await waitForElementToBeRemoved(() => getByText('find keys'))
+
+    assert.strictEqual(await Task.query().resultSize(), 0)
   })
 })
```

Compared to the fully end-to-end test we wrote with puppeteer above, which depended on a lot of CSS classes to make the query selectors work, this *mostly* end-to-end test with `jsdom` uses React Test Library matchers that are hopefully much less fragile and more closely resemble how the user uses the application, improving the fidelity of the test. One disadvantage is that we [lose](https://github.com/jdleesmiller/todo-demo/commit/517f458b402f4d028dfe06ca43905a8f5deff38b) the ability to run the frontend integration test in a normal browser, where loading the `storage` package is impossible, but we could still run the rest of the frontend tests in a normal browser. End-to-end testing with `jsdom` instead of a full headless browser is worth considering for many applications.

### Conclusions

In this post we've added end-to-end tests to our example TODO list application. We've seen how to:
- Create separate test and development environments with Docker Compose, while still sharing some resources between environments for efficiency.
- Write scripts to help manage the more complicated `docker-compose` commands required for this approach.
- Extract the model layer into its own package to allow tests to access the database.
- Use puppeteer via Docker in the test environment for an end-to-end test using a headless browser.
- Use `jsdom` in the test environment for a lighter weight approach to (mostly) end-to-end testing, blurring the boundary somewhat between frontend integration testing and end-to-end testing.

Next time, we'll expand into the world of multiple backend services and explore some strategies for managing and testing them. Until then, happy testing!

---

<p>&nbsp;</p>

If you've read this far, you should [follow me on twitter](https://twitter.com/jdleesmiller), or maybe even apply to work at [Overleaf](https://www.overleaf.com). `:)`

<p>&nbsp;</p>

### Footnotes

[^suffix]: The numeric suffix is so you can run multiple instances of the same container with the `--scale` flag to [`docker-compose up`](https://docs.docker.com/compose/reference/up/). We won't use this feature here.

[^project-name]: One disadvantage of hard coding the project name in this way is that you can't run two instances of the project in different folders, which the default Compose behavior of using the directory name as the project name allows. Setting it based on `$(basename $(pwd))` would bring this back.
