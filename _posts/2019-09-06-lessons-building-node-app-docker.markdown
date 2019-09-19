---
layout: post
title: "Lessons from Building Node Apps in Docker (2019)"
date: 2019-09-06 16:00:00 +0000
categories: articles
image: /assets/docker_chat_demo/chat.png
description: Here are some tips and tricks I've learned for developing and deploying web applications written for node.js using Docker (2019 edition).
---

Way back in 2016, I wrote [Lessons from Building a Node App in Docker](/articles/2016/03/06/lessons-building-node-app-docker.html), which has now helped over a hundred thousand people Dockerize their node.js apps. Since then there have been many changes, both in the ecosystem and how I work with node in Docker, so it was due for an overhaul.

In this updated tutorial, we'll set up the [socket.io chat example](http://socket.io/get-started/chat/) with Docker, from scratch to production-ready. In particular, we'll see how to:

* Get started bootstrapping a node application with Docker.
* Not run everything as root (bad!).
* Use binds to keep your test-edit-reload cycle short in development.
* Manage `node_modules` in a container (there's a trick to this).
* Ensure repeatable builds with [package-lock.json](https://docs.npmjs.com/files/package-lock.json).
* Share a `Dockerfile` between development and production using multi-stage builds.

This tutorial assumes you already have some familiarity with Docker and node. If you’d like a gentle intro to Docker first, I'd recommend running through [Docker's official introduction](https://docs.docker.com/get-started/).

### Getting Started

We're going to set things up from scratch. The final code is available [on github here](https://github.com/jdleesmiller/docker-chat-demo), and there are tags for each step along the way. [Here's the code for the first step](https://github.com/jdleesmiller/docker-chat-demo/tree/2019-01-bootstrapping), in case you'd like to follow along.

Without Docker, we'd start by installing node and any other dependencies on the host and running `npm init` to create a new package. There's nothing stopping us from doing that here, but we'll learn more if we use Docker from the start. (And of course the whole point of using Docker is that you don't have to install things on the host.) We'll start by creating a "bootstrapping container" that has node installed, and we'll use it to set up the npm package for the application.

#### The Bootstrapping Container and Service

We'll need to write two files, a `Dockerfile` and a `docker-compose.yml`, to which we'll add more later on. Let's start with the bootstrapping `Dockerfile`:

```Dockerfile
FROM node:10.16.3

USER node

WORKDIR /srv/chat
```

It's a short file, but there already some important points:

1. It starts from the official Docker image for the latest long term support (LTS) node release, at time of writing. I prefer to name a specific version, rather than one of the 'floating' tags like `node:lts` or `node:latest`, so that if you or someone else builds this image on a different machine, they will get the same version, rather than risking an accidental upgrade and attendant head-scratching.

1. The `USER` step tells Docker to run any subsequent build steps, and later the process in the container, as the `node` user, which is an unprivileged user that comes built into all of the official node images from Docker. Without this line, they would run as **root**, which is against security best practices and in particular the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege). Many Docker tutorials skip this step for simplicity, and we will have to do some extra work to avoid running as root, but I think it's very important.

1. The `WORKDIR` step sets the working directory for any subsequent build steps, and later for containers created from the image, to `/srv/chat`, which is where we'll put our application files. The `/srv` folder should be available on any system that follows the [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/fhs.shtml), which says that it is for "site-specific data which is served by this system", which sounds like a good fit for a node app [^srv].

Now let’s move on to the bootstrapping compose file, `docker-compose.yml`:

```yaml
version: '3.7'

services:
  chat:
    build: .
    command: echo 'ready'
    volumes:
      - .:/srv/chat
```

Again there is quite a bit to unpack:

1. The `version` line tells Docker Compose which version of its [file format](https://docs.docker.com/compose/compose-file) we are using. Version 3.7 is the latest at the time of writing, so I've gone with that, but older 3.x and 2.x versions would also work fine here; in fact, the 2.x series might even be a better fit, depending on your use case [^compose-file-v2].

1. The file defines a single service called `chat`, built from the `Dockerfile` in the current directory, denoted `.`. All the service does for now is to echo `ready` and exit.

1. The volume line, `.:/srv/chat`, tells Docker to bind mount the current directory `.` on the host at `/srv/chat` in the container, which is the `WORKDIR` we set up in the `Dockerfile` above. This means that changes we'll make to source files on the host will be automatically reflected inside the container, and vice versa. This is very important for keeping your test-edit-reload cycles as short as possible in development. It will, however, create some issues with how npm installs dependencies, which we'll come back to shortly.

Now we're ready to build and test our bootstrapping container. When we run `docker-compose build`, Docker will create an image with node set up as specified in the `Dockerfile`. Then `docker-compose up` will start a container with that image and run the echo command, which shows that everything is set up OK.

```shell
$ docker-compose build
Building chat
Step 1/3 : FROM node:10.16.3
# ... more build output ...
Successfully built d22d841c07da
Successfully tagged docker-chat-demo_chat:latest

$ docker-compose up
Creating docker-chat-demo_chat_1 ... done
Attaching to docker-chat-demo_chat_1
chat_1  | ready
docker-chat-demo_chat_1 exited with code 0
```

This output indicates that the container ran, echoed `ready` and exited successfully. 🎉

#### Initializing an npm package

> ⚠️ Aside for Linux users: For this next step to work smoothly, the `node` user in the container should have the same `uid` (user identifier) as your user on the host. This is because the user in the container needs to have permissions to read and write files on the host via the bind mount, and vice versa. I've included [an appendix with advice on how to deal with this issue](#appendix-dealing-with-uid-mismatches-on-linux). Docker for Mac users don't have to worry about it because of some uid remapping magic behind the scenes, but Docker for Linux get much better performance, so I'd call it a draw.

Now we have a node environment set up in Docker, we're ready to set up the initial npm package files. To do this, we'll run an interactive shell in the container for the `chat` service and use it to set up the initial package files:

```shell
$ docker-compose run --rm chat bash
node@467aa1c96e71:/srv/chat$ npm init --yes
# ... writes package.json ...
node@467aa1c96e71:/srv/chat$ npm install
# ... writes package-lock.json ...
node@467aa1c96e71:/srv/chat$ exit
```

And then the files appear on the host, ready for us to commit to version control:

```shell
$ tree
.
├── Dockerfile
├── docker-compose.yml
├── package-lock.json
└── package.json
```

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/2019-02-bootstrapped).

## Installing Dependencies

Next up on our list is to install the app's dependencies. We want these dependencies to be installed inside the container via the `Dockerfile`, so the container will contain everything needed to run the application. This means we need to get the `package.json` and `package-lock.json` files into the image and run `npm install` in the `Dockerfile`. Here's what that change looks like:

```diff
diff --git a/Dockerfile b/Dockerfile
index b18769e..d48e026 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -1,5 +1,14 @@
 FROM node:10.16.3

+RUN mkdir /srv/chat && chown node:node /srv/chat
+
 USER node

 WORKDIR /srv/chat
+
+COPY --chown=node:node package.json package-lock.json ./
+
+RUN npm install --quiet
+
+# TODO: Can remove once we have some dependencies in package.json.
+RUN mkdir -p node_modules
```

And here's the explanation:

1. The `RUN` step with `mkdir` and `chown` commands, which are the only commands we need to run as root, creates the working directory and makes sure that it's owned by the node user.

1. It's worth noting that there are two shell commands chained together in that single `RUN` step. Compared to splitting out the commands over multiple `RUN` steps, chaining them reduces the number of layers in the resulting image. In this example, it really doesn't matter very much, but it is a [good habit](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) not to use more layers than you need. It can save a lot of disk space and download time if you e.g. download a package, unzip it, build it, install it, and then clean up in one step, rather than saving layers with all of the intermediate files for each step.

1. The `COPY` to `./` copies the npm packaging files to the `WORKDIR` that we set up above. The trailing `/` tells Docker that the destination is a folder. The reason for copying in only the packaging files, rather than the whole application folder, is that Docker will cache the results of the `npm install` step below and rerun it only if the packaging files change. If we copied in all our source files, changing any one would bust the cache even though the required packages had not changed, leading to unnecessary `npm install`s in subsequent builds.

1. The `--chown=node:node` flag for `COPY` ensures that the files are owned by the unprivileged `node` user rather than root, which is the default [^build-as-root].

1. The `npm install` step will run as the `node` user in the working directory to install the dependencies in `/srv/chat/node_modules` inside the container. This is what we want, but it causes a problem in development when we bind mount the application folder on the host over `/srv/chat`. Unfortunately, the `node_modules` folder doesn't exist on the host, so the bind effectively hides the node modules that we installed in the image. The final `mkdir -p node_modules` step and the next section are related to how we deal with this.

### The `node_modules` Volume Trick

There are [several](https://github.com/docker/example-voting-app/blob/7629961971ab5ca9fdfeadff52e7127bd73684a5/result-app/Dockerfile#L8) [ways](http://bitjudo.com/blog/2014/03/13/building-efficient-dockerfiles-node-dot-js/) [around](https://semaphoreci.com/community/tutorials/dockerizing-a-node-js-web-application) this node modules hiding problem, but I think the most elegant is to [use a volume](http://stackoverflow.com/questions/30043872/docker-compose-node-modules-not-present-in-a-volume-after-npm-install-succeeds) within the bind to contain `node_modules`. To do this, we have to add a few lines to our docker compose file:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index c9a2543..799e1f6 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -6,3 +6,7 @@ services:
     command: echo 'ready'
     volumes:
       - .:/srv/chat
+      - chat_node_modules:/srv/chat/node_modules
+
+volumes:
+  chat_node_modules:
```

The `chat_node_modules:/srv/chat/node_modules` volume line sets up a *named volume* [^named-volume] called `chat_node_modules` that contains the directory `/srv/chat/node_modules` in the container. The top level `volumes:` section at the end must declare all named volumes, so we add `chat_node_modules` there, too.

So, it's simple to do, but there is quite a bit going on behind the scenes to make it work:

1. During the build, `npm install` installs the dependencies (which we'll add in the next section) into `/srv/chat/node_modules` within the image. We'll color the files from the image blue:
   <pre style="color: blue;">
/srv/chat$ tree # in image
.
├── node_modules
│   ├── accepts
...
│   └── yeast
├── package-lock.json
└── package.json
   </pre>

1. When we later start a container from that image using our compose file, Docker first binds the application folder from the host inside the container under `/srv/chat`. We'll color the files from the host red:
   <pre style="color: red;">
/srv/chat$ tree # in container without node_modules volume
.
├── Dockerfile
├── docker-compose.yml
├── node_modules
├── package-lock.json
└── package.json
   </pre>
   The bad news is that the `node_modules` in the image are hidden by the bind; inside the container, we instead see only an empty `node_modules` folder on the host.

1. However, we're not done yet. Docker next creates a *volume* that contains a copy of `/srv/chat/node_modules` in the image, and it mounts it in the container. This, in turn, hides the `node_modules` from the bind on the host:
   <pre style="color: red;">
/srv/chat$ tree # in container with node_modules volume
.
├── Dockerfile
├── docker-compose.yml<div style="color: blue;">├── node_modules
│   ├── accepts
...
│   └── yeast</div>├── package-lock.json
└── package.json
   </pre>

This gives us what we want: our source files on the host are bound inside the container, which allows for fast changes, and the dependencies are also available inside of the container, so we can use them to run the app.

We can also now explain the final `mkdir -p node_modules` step in the bootstrapping `Dockerfile` above: we have not actually installed any packages yet, so `npm install` doesn't create the `node_modules` folder during the build. When Docker creates the `/srv/chat/node_modules` volume, it will automatically create the folder for us, but it will be owned by root, which means the node user won't be able to write to it. We can preempt that by creating `node_modules` as the node user during the build. Once we have some packages installed, we no longer need this line.

### Package Installation

So, let's rebuild the image, and we'll be ready to install packages.

```shell
$ docker-compose build
... builds and runs npm install (with no packages yet)...
```

The chat app requires express, so let's get a shell in the container and `npm install` it with `--save` to save the dependency to our `package.json` and update `package-lock.json` accordingly:

```shell
$ docker-compose run --rm chat bash
Creating volume "docker-chat-demo_chat_node_modules" with default driver
node@241554e6b96c:/srv/chat$ npm install --save express
# ...
node@241554e6b96c:/srv/chat$ exit
```

The `package-lock.json` file, which has for most purposes replaced the older `npm-shrinkwrap.json` file, is important for ensuring that Docker image builds are repeatable. It records the versions of all direct and indirect dependencies and ensures that `npm install`s in Docker builds on different machines will all get the same dependency tree.

Finally, it's worth noting that the `node_modules` we installed are not present on the host. There may be an empty `node_modules` folder on the host, which is a side effect of the binds and volumes we created, but the actual files live in the `chat_node_modules` volume. If we run another shell in the `chat` container, we'll find them there:

```shell
$ ls node_modules
# nothing on the host
$ docker-compose run --rm chat bash
node@54d981e169de:/srv/chat$ ls -l node_modules/
total 196
drwxr-xr-x 2 node node 4096 Aug 25 20:07 accepts
# ... many node modules in the container
drwxr-xr-x 2 node node 4096 Aug 25 20:07 vary
```

The next time we run a `docker-compose build`, the modules will be installed into the image.

Here’s the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/2019-03-dependencies).

## Running the App

We are finally ready to install the app, so we'll copy in [the remaining source files](https://github.com/socketio/chat-example), namely `index.js` and `index.html`.

Then we'll install the `socket.io` package. At the time of writing, the chat example is only compatible with socket.io version 1, so we need to request version 1:

```sh
$ docker-compose run --rm chat npm install --save socket.io@1
# ...
```

In our docker compose file, we then remove our dummy `echo ready` command and instead run the chat example server. Finally, we tell Docker Compose to export 3000 in the container on the host, so we can access it in a browser:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index 799e1f6..ff92767 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -3,7 +3,9 @@ version: '3.7'
 services:
   chat:
     build: .
-    command: echo 'ready'
+    command: node index.js
+    ports:
+      - '3000:3000'
     volumes:
       - .:/srv/chat
       - chat_node_modules:/srv/chat/node_modules
```

Then we are ready to run with `docker-compose up` [^no-build]:

```shell
$ docker-compose up
Recreating dockerchatdemo_chat_1
Attaching to dockerchatdemo_chat_1
chat_1 | listening on *:3000
```

Then you can see it running on `http://localhost:3000`.

![Docker chat demo working!](/assets/docker_chat_demo/chat.png)

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/2019-04-the-app).

## Docker for Dev and Prod

We now have our app running in development under docker compose, which is pretty cool! Before we can use this container in production, we have a few problems to solve and possible improvements to make:

- Most importantly, the container as we're building it at the moment does not actually contain the source code for the application --- it just contains the npm packaging files and dependencies. The main idea of a container is that it should contain everything needed to run the application, so clearly we will want to change this.

- The `/srv/chat` application folder in the image is currently owned and writeable by the `node` user. Most applications don't need to rewrite their source files at runtime, so again applying the principle of least privilege, we shouldn't let them.

- The image is fairly large, weighing in at 909MB according to the handy [dive](https://github.com/wagoodman/dive) image inspection tool. It's not worth obsessing over image size, but we don't want to be needlessly wasteful either. Most of the image's heft comes from the default `node` base image, which includes a full compiler tool chain that lets us build node modules that use native code (as opposed to pure JavaScript). We won't need that compiler tool chain at runtime, so from both a security and performance point of view, it would be better not to ship it to production.

Fortunately, Docker provide a powerful tool that helps with all of the above: multi-stage builds. The main idea is that we can have multiple `FROM` commands in the `Dockerfile`, one per stage, and each stage can copy files from previous stages. Let's see how to set that up:

```diff
diff --git a/Dockerfile b/Dockerfile
index d48e026..6c8965d 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -1,4 +1,4 @@
-FROM node:10.16.3
+FROM node:10.16.3 AS development

 RUN mkdir /srv/chat && chown node:node /srv/chat

@@ -10,5 +10,14 @@ COPY --chown=node:node package.json package-lock.json ./

 RUN npm install --quiet

-# TODO: Can remove once we have some dependencies in package.json.
-RUN mkdir -p node_modules
+FROM node:10.16.3-slim AS production
+
+USER node
+
+WORKDIR /srv/chat
+
+COPY --from=development --chown=root:root /srv/chat/node_modules ./node_modules
+
+COPY . .
+
+CMD ["node", "index.js"]
```

1. Our existing `Dockerfile` steps will form the first stage, which we'll now give the name `development` by adding `AS development` to the `FROM` line at the start. I've now removed the temporary `mkdir -p node_modules` step needed during bootstrapping, since we now have some packages installed.

1. The new second stage starts with the second `FROM` step, which pulls in the `slim` node base image for the same node version and calls the stage `production` for clarity. This `slim` image is also an [official node image](https://hub.docker.com/_/node) from Docker. As its name suggests, it is smaller than the default `node` image, mainly because it doesn't include the compiler toolchain; it includes only the system dependencies needed to run a node application, which are far fewer than what may be required to build one.

    This multi-stage `Dockerfile` runs `npm install` in the first stage, which has the full node image at its disposal for the build. Then it copies the resulting `node_modules` folder to the second stage image, which uses the `slim` base image. This technique reduces the size of the production image from 909MB to 152MB, which is about a factor of 6 saving for relatively little effort [^alpine].

1. Again the `USER node` command tells Docker to run the build and the application as the unprivileged `node` user rather than as root. We also have to repeat the `WORKDIR`, because it doesn't persist into the second stage automatically.

1. The `COPY --from=development --chown=root:root ...` line copies the dependencies installed in the preceding `development` stage into the production stage and makes them owned by root, so the node user can read but not write them.

1. The `COPY . .` line then copies the rest of the application files from the host to the working directory in the container, namely `/srv/chat`.

1. Finally, the `CMD` step specifies the command to run. In the development stage, the application files came from bind mounts set up with docker-compose, so it made sense to specify the command in the `docker-compose.yml` file instead of the `Dockerfile`. Here it makes more sense to specify the command in the `Dockerfile`, which builds it into the container.

Now that we have our multi-stage `Dockerfile` set up, we need to tell Docker Compose to use only the `development` stage rather than going through the full `Dockerfile`, which we can do with the `target` option:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index ff92767..2ee0d9b 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -2,7 +2,9 @@ version: '3.7'

 services:
   chat:
-    build: .
+    build:
+      context: .
+      target: development
     command: node index.js
     ports:
       - '3000:3000'
```

This will preserve the old behavior we had before we added multistage builds, in development.

Finally, to make the `COPY . .` step in our new `Dockerfile` safe, we should add a `.dockerignore` file. Without it, the `COPY . .` may pick up other things we don't need or want in our production image, such as our `.git` folder, any `node_modules` that are installed on the host outside of Docker, and indeed all the Docker-related files that go into building the image. Ignoring these leads to smaller images and also faster builds, because the Docker daemon does not have to work as hard to create its copy of the files for its build context. Here's the `.dockerignore` file:
```
.dockerignore
.git
docker-compose*.yml
Dockerfile
node_modules
```

With all of that set up, we can run a production build to simulate how a CI system might build the final image, and then run it like an orchestrator might:
```shell
$ docker build . -t chat:latest
# ... build output ...
$ docker run --rm --detach --publish 3000:3000 chat:latest
dd1cf2bf9496edee58e1f5122756796999942fa4437e289de4bd67b595e95745
```
and again access it in the browser on `http://localhost:3000`. When finished, we can stop it using the container ID from the command above [^signals].
```shell
$ docker stop dd1cf2bf9496edee58e1f5122756796999942fa4437e289de4bd67b595e95745
```

### Setting up `nodemon` in Development

Now that we have distinct development and production images, let's see how to make the development image a bit more developer-friendly by running the application under [nodemon](https://github.com/remy/nodemon) for automatic reloads within the container when we change a source file. After running
```shell
$ docker-compose run --rm chat npm install --save-dev nodemon
```
to install nodemon, we can update the compose file to run it:
```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index 2ee0d9b..173a297 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -5,7 +5,7 @@ services:
     build:
       context: .
       target: development
-    command: node index.js
+    command: npx nodemon index.js
     ports:
       - '3000:3000'
     volumes:
```

Here we use [`npx`](https://blog.npmjs.org/post/162869356040/introducing-npx-an-npm-package-runner) to run nodemon through npm [^npm]. When we bring up the service, we should see the familiar `nodemon` output [^nodemon-rs]:

```
docker-compose up
Recreating docker-chat-demo_chat_1 ... done
Attaching to docker-chat-demo_chat_1
chat_1  | [nodemon] 1.19.2
chat_1  | [nodemon] to restart at any time, enter `rs`
chat_1  | [nodemon] watching dir(s): *.*
chat_1  | [nodemon] starting `node index.js`
chat_1  | listening on *:3000
```

Finally, it's worth noting that with the `Dockerfile` above the dev dependencies will be included in the production image. It is possible to break out another stage to avoid this, but I would argue it is not necessarily a bad thing to include them. Nodemon is unlikely to be wanted in production, it is true, but dev dependencies often include testing utilities, and including those means we can run the tests in our production container as part of CI. It also generally improves dev-prod parity, and as some [wise people once said](http://llis.nasa.gov/lesson/1196), 'test as you fly, fly as you test.' Speaking of which, we don't have any tests, but it's easy enough to run them when we do:

```shell
$ docker-compose run --rm chat npm test

> chat@1.0.0 test /srv/chat
> echo "Error: no test specified" && exit 1

Error: no test specified
npm ERR! Test failed.  See above for more details.
```

Here's the [final code on github](https://github.com/jdleesmiller/docker-chat-demo).

## Conclusion

We've taken an app and got it running in development and production entirely within Docker. Great job!

We jumped through some hopefully edifying hoops to bootstrap a node environment without installing anything on the host. We also jumped through some hoops to avoid running builds and processes as root, instead running them as an unprivileged user for better security.

Node / npm's habit of putting dependencies in the `node_modules` subfolder makes our lives a little bit more complicated than other solutions, such as ruby's bundler, that install your dependencies outside the application folder, but we were able to work around that fairly easily with the nested node modules volume trick.

Finally, we used Docker's multi-stage build feature to produce a `Dockerfile` suitable for both development and production. This simple but powerful feature is useful in a wide variety of situations, and we'll see it again in some future articles.

My next article in this series will pick up where we left off about testing node.js services in Docker. See you then!

<p>&nbsp;</p>
---
<p>&nbsp;</p>

If you've read this far, you should [follow me on twitter](https://twitter.com/jdleesmiller), or maybe even apply to work at [Overleaf](https://www.overleaf.com). `:)`

<p>&nbsp;</p>
---
<p>&nbsp;</p>

# Appendix: Dealing with UID mismatches on Linux

When using bind mounts to share files between a Linux host and a container, you are likely to hit permissions problems if the numeric uid of the user in the container doesn't match that of the user on the host. For example, files created on the host may not be readable or writable in the container, or vice versa.

We can work around this, but first it's worth noting that if your uid on the host is 1000, everything is fine for Dockerized development with node. This is because Docker's official node images all use uid 1000 for the node user. You can check your uid on the host by running the `id` command, which prints it out. For example, mine currently says `uid=1000(john) gid=1000(john) ...`.

A uid of 1000 is fairly common, because it is the uid assigned by the ubuntu install process. If you can convince everyone on your team to set their uid to 1000, everything will work fine. If not, here are a couple of workarounds:

1. Run the service as root in development by simply omitting the `USER node` step from the development stage of the Dockerfile (introduced in the [Docker for Dev and Prod](#docker-for-dev-and-prod) section). This ensures that the user in the container (root) will be able to read and write files on the host. If the user in the container creates any files, they'll be owned as root on the host, but you can always fix that by running `sudo chown -R your-user:your-group .` on the host.

   You can (and should) still run the process as an unprivileged user in production.

2. Use Dockerfile [build arguments](https://docs.docker.com/engine/reference/builder/#arg) to configure the UID and GID of the node user at build time. We can do this by adding a few lines to the development stage of the `Dockerfile`:
   ```Dockerfile
   FROM node:10.16.3 AS development
   
   ARG UID=1000
   ARG GID=1000
   RUN \
     usermod --uid ${UID} node && groupmod --gid ${GID} node &&\
     mkdir /srv/chat && chown node:node /srv/chat

   # ...
   ```
   This introduces two build args, `UID` and `GID`, which default to the existing value of 1000 if no arguments are given, and changes the `node` user and group to use those IDs before creating any files as the user.

   Each developer with a non-1000 uid/gid has to set these `args` for Docker Compose. One way to do this is to use a `docker-compose.override.yml` file that is not checked into version control (i.e. is in `.gitignore`), to set the `args`, like this:
   ```yaml
   version: '3.7'
   
   services:
     chat:
       build:
         args:
           UID: '500'
           GID: '500'
   ```
   In this example, the uid and gid in the container will be set to 500. There may be some easier ways of doing this [one day](https://github.com/docker/compose/issues/2380). Again, these changes only need to be done in the development stage, not production.

# Footnotes

[^srv]: Fundamentally, it doesn't matter where the files go in the container. `/opt` would also be a very reasonable choice. Another option would be to keep them under `/home/node`, which simplifies some file permissions management in development but requires more typing and makes less sense in production, where I'll advocate letting root own the application files as a way of keeping them read only. In any case, `/srv` will do.

[^compose-file-v2]: Both the 2.x and 3.x versions of the Docker Compose file format are still being actively developed. The main benefit of the 3.x series is that it is cross-compatible between single-node applications running on Docker Compose and multi-node applications running on Docker Swarm. In order to be compatible, version 3 drops some useful features from version 2. If you are only interested in Docker Compose, you might prefer to stick with the [latest 2.x format](https://docs.docker.com/compose/compose-file/compose-file-v2/).

[^build-as-root]: Some of this trickery in the `Dockerfile` can be removed if we allow the `npm install` build step to run as root. If we do, we can and should still use the unprivileged node user at runtime, which is where most of the security benefits reside. A `Dockerfile` to run the build as root and the container as the node user would look more like this:
    ```Dockerfile
    FROM node:10.16.3

    WORKDIR /srv/chat

    COPY package.json package-lock.json ./

    RUN npm install --quiet

    USER node
    ```

    This is cleaner, without the need for some `mkdir` and `chown` tricks, at the expense of running `npm install` as root at build time. Overall, I think the modest increase in complexity is worth it to avoid running the build as root, but you might decide that you prefer the cleaner `Dockerfile`.

    One caveat if you build as root is that when you want to later install new dependencies you need to run a shell as root instead of the node user, as in `docker-compose run --rm --user root chat bash` and then `npm install --save express`. This is a bit like "sudoing" to install packages, which is a fairly familiar experience.

[^named-volume]: We could instead use an *anonymous volume* to contain the modules, just by omitting the name:
    ```diff
    diff --git a/docker-compose.yml b/docker-compose.yml
    index c9a2543..5a56364 100644
    --- a/docker-compose.yml
    +++ b/docker-compose.yml
    @@ -6,3 +6,4 @@ services:
         command: echo 'ready'
         volumes:
           - .:/srv/chat
    +      - /srv/chat/node_modules
    ```
    That would be shorter, but it is very easy to forget to clean up anonymous volumes, which leads to a profusion of anonymous modules with no indication which container they came from. You can still clean them up with `docker system prune`, but that is a bit of a 'sledge hammer to crack a nut'. The named volumes approach is a bit more verbose but also more transparent.

    (Extra credit: you might wonder where those dependency files in the volume actually get stored. In short, whether using named or anonymous volumes, they live in a separate directory managed by Docker on the host; see the [Docker docs about volumes](https://docs.docker.com/storage/volumes/) for more info.)

[^no-build]: The eagle eyed reader may have noticed that we don't have to `docker-compose build` to get the dependencies installed before `docker-compose up`. This is because it is running with the node modules in the `chat_node_modules` named volume. The next time we do a build, npm will install the dependencies from scratch into the image, but for installing packages day-to-day, we can just run `npm install` in the container without having to rebuild.

    If you ever find yourself in a situation where you want to get rid of the named volume and start from scratch, you can run `docker volume list` to get a list of all volumes. The full name of your node modules volume will depend on your docker compose project. In my case, the volume of interest is `docker-chat-demo_chat_node_modules`, which can be removed if we first remove the container with `docker-compose rm -v chat` and then the volume itself with `docker volume rm docker-chat-demo_chat_node_modules`.

[^alpine]: Docker also provides an official `alpine` image variant that is even smaller. However, these size savings come in part from using a completely different [`libc`](https://en.wikipedia.org/wiki/C_standard_library) and package manager than the Debian-based images. Unless you are deploying to embedded systems where space is at a premium, the complexities that may arise due to these differences may not be worth it, especially when the Debian-based slim images already offer substantial savings.

[^signals]: You might notice that it takes about 10s to stop. This is because the socket.io chat example does not correctly handle the `SIGTERM` signal, which Docker sends it when it's time to stop, to perform a graceful shutdown. Extra credit: add this code to the end of `index.js`:
    ```js
    process.on('SIGTERM', function() {
      io.close();
      Object.values(io.of('/').connected).forEach(s => s.disconnect(true));
    });
    ```
    then rebuild the production image and try to run and `docker stop` the container again. It should disconnect any clients and stop promptly after that change.

[^npm]: Using npm to run processes in containers is sometimes discouraged, but I think that advice is out of date. Older versions of npm did have problems [handling signals](https://github.com/npm/npm/pull/10868) needed to cleanly shut down processes, but this should be fixed in recent versions. If your containers always seem to take 10s to shut down, it's likely that they are not listening for the `SIGTERM` signal to initiate a graceful shutdown; see [^signals]. Running the process through `npm` does create some overhead, namely an additional node process, so you may want to avoid it in production, but in development it is usually fine.

[^nodemon-rs]: You may notice that nodemon says that typing `rs` will restart it. That won't work if we use `docker-compose up` to bring up the service, because our terminal is not connected to nodemon's standard input when we do that. If we run `docker-compose run --rm chat` instead, `rs` should work as usual; this can be useful when working on one service in particular.
