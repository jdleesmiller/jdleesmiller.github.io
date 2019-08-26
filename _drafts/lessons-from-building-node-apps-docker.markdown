---
layout: post
title: "Lessons from Building Node Apps in Docker (2019)"
date: 2019-08-26 20:00:00 +0000
categories: articles
image: /assets/docker_chat_demo/chat.png
description: Here are some tips and tricks I've learned for developing and deploying web applications written for node.js using Docker (2019 edition).
---

Way back in 2016, I wrote [Lessons from Building a Node App in Docker](/articles/2016/03/06/lessons-building-node-app-docker.html), which has now helped over a hundred thousand people Dockerize their node.js apps. Since then, there have been many changes, both in the ecosystem and how I work with node in Docker, so I think it is due for an update.

Like last time, we'll see how to set up the [socket.io chat example](http://socket.io/get-started/chat/) in Docker, from scratch to production-ready. In particular, we'll see how to:

* Get started bootstrapping a node application with Docker.
* Not run everything as root (bad!).
* Use binds to keep your test-edit-reload cycle short in development.
* Manage `node_modules` in a container (there's a trick to this).
* Ensure repeatable builds with [package-lock.json](https://docs.npmjs.com/files/package-lock.json).
* Share a `Dockerfile` between development and production using multi-stage builds.

This tutorial assumes you already have some familiarity with Docker and node. If you’d like a gentle intro to Docker first, I'd recommend running through [Docker's official introduction](https://docs.docker.com/get-started/).

### Getting Started

We're going to set things up from scratch. The final code is available [on github here](https://github.com/jdleesmiller/docker-chat-demo), and there are tags for each step along the way. [Here's the code for the first step](https://github.com/jdleesmiller/docker-chat-demo/tree/01-bootstrapping), in case you'd like to follow along.

Without Docker, we'd start by installing node and any other dependencies on the host and running `npm init` to create a new package. There's nothing stopping us from doing that here, but we'll learn more if we use Docker from the start. (And of course the whole point of using Docker is that you don't have to install things on the host.) We'll start by creating a "bootstrapping container" that has node installed, and we'll use it to set up the npm package for the application.

#### The Bootstrapping Container and Service

We'll need to write two files, a `Dockerfile` and a `docker-compose.yml`, to which we'll add more later on. Let's start with the bootstrapping `Dockerfile`:

```Dockerfile
FROM node:10.16.3

USER node

RUN mkdir /home/node/chat

WORKDIR /home/node/chat
```

It's a short file, but there already some important points:

1. It starts from the official Docker image for the latest long term support (LTS) node release, at time of writing. I prefer to name a specific version, rather than one of the 'floating' tags like `node:lts` or `node:latest`, so that if you or someone else builds this image on a different machine, they will get the same version, rather than risking an accidental upgrade and attendant head-scratching.

1. It asks Docker to run the build steps and later the processes in the container as the `node` user, which is an unprivileged user that comes built into all of the official Docker images for node. Without this, processes inside the container run as **root**, which is against security best practices and in particular the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege). Many docker tutorials skip this step for simplicity, and we will have to do some extra work to make things work, but I think it's very important.

1. It sets up a working directory in the unprivileged `node` user's home directory where our application will live in the container. If we didn't run `mkdir` first to create the directory, the `WORKDIR` Dockerfile command would create it for us automatically, but it would be owned by root rather than the `node` user, which would cause file permissions problems below.

Now let’s move on to the bootstrapping compose file, `docker-compose.yml`:

```yaml
version: '3.7'

services:
  chat:
    build: .
    command: echo 'ready'
    volumes:
      - .:/home/node/chat
```

Again there is quite a bit to unpack:

1. The `version` line tells Docker Compose which version of its [file format](https://docs.docker.com/compose/compose-file) we are using. Version 3.7 is the latest at the time of writing, so I've gone with that, but older 3.x and 2.x versions would also work fine here; in fact, they might even be a better fit, depending on your use case [^compose-file-v2].

1. The file defines a single service, built from the `Dockerfile` in the current directory, denoted `.`. All the service does for now is to echo `ready` and exit.

1. The volume line, `.:/home/node/chat`, tells Docker to mount the current directory `.` on the host at the `/home/node/chat` in the container, which is the `WORKDIR` we set up in the `Dockerfile` above. This means that changes we'll make to source files on the host will be automatically reflected inside the container, and vice versa. This is very important for keeping your test-edit-reload cycles as short as possible in development. It will create some issues with how npm installs dependencies, which we'll come back to.

For now, however, we're ready to build and test our bootstrapping container. When we run `docker-compose build`, Docker will create an image with node set up as specified in the `Dockerfile`. Then `docker-compose up` will start a container with that image and run the echo command, which shows that everything is set up OK.

```shell
$ docker-compose build
Building chat
Step 1/4 : FROM node:10.16.3
# ...
# lots of build (and, the first time, download) output
# ...
Successfully built 4616c3a609cf
Successfully tagged docker-chat-demo_chat:latest

$ docker-compose up
Creating docker-chat-demo_chat_1 ... done
Attaching to docker-chat-demo_chat_1
chat_1  | ready
docker-chat-demo_chat_1 exited with code 0
```

This output indicates that the container ran, echoed `ready` and exited successfully. 🎉

#### Initializing an npm package

Now we have a node environment set up in Docker, we're ready to set up the initial npm package files. To do this, we'll run an interactive shell in the container for the `chat` service and use it to set up the initial package files.

> ⚠️ Aside for Linux users: For this next step to work smoothly, the `node` user in the container should have the same `uid` (user identifier) as your user on the host. This is because the `node` user in the container will create files on the host via a bind mount; if the uid doesn't match between host and container, your user on the host may not be able to read or write them. See Appendix A for some workarounds for this problem. Docker for Mac users don't have to worry about this because of some uid remapping magic going on behind the scenes, but Docker for Linux get much better performance, so I'd call this a draw.

```shell
$ docker-compose run --rm chat bash
node@467aa1c96e71:~/chat$ npm init --yes
# ... writes package.json ...
node@467aa1c96e71:~/chat$ npm install
# ... writes package-lock.json ...
node@467aa1c96e71:~/chat$ exit
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

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/02-bootstrapped).

## Installing Dependencies

Next up on our list is to install the app's dependencies. We want these dependencies to be installed inside the container via the `Dockerfile`, so the container contains everything needed to run the application.

In order to do this, we need to run `npm install` in the `Dockerfile`, and, before we do that, we need to get the `package.json` and `package-lock.json` files into the image so `npm` can read them. Here's what that change looks like:

```diff
diff --git a/Dockerfile b/Dockerfile
index 7dd8ad6..a32e2e5 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -2,6 +2,10 @@ FROM node:10.16.3

 USER node

-RUN mkdir /home/node/chat
+RUN mkdir -p /home/node/chat/node_modules

 WORKDIR /home/node/chat
+
+COPY --chown=node:node package.json package-lock.json ./
+
+RUN npm install --quiet
```

And the explanation:

1. The change to the `mkdir` command is setting us up to avoid a permissions issue in the next step. It's only needed during bootstrapping, when we don't have any `node_modules` actually installed yet; more on this below!

1. We could `COPY` the whole application folder on the host into the container, rather than just the packaging files, but we'll see later that we can save some time on our docker builds by only copying in what we need at this point, and copying in the rest after we run `npm install`. This takes better advantage of `docker build`'s layer caching.

1. The `COPY` to `./` copies to the `WORKDIR` that we set up on the previous line. Note that the trailing `/` tells Docker that the destination is a folder, and it is required, because it would not make much sense to copy two files to a destination that isn't a folder.

1. The `--chown=node:node` flag for `COPY` ensures that the files are owned by the unprivileged `node` user rather than root, which is the default. This is important, because we'll want the `node` user to be able to write to those files, at least during development.

1. Finally, the `npm install` step will run as the `node` user and install the dependencies in `~/chat/node_modules` inside the container.

That last point causes some trouble when we use the image in development, because we will bind mount the application folder on the host over `~/chat` inside the container. Unfortunately, the `node_modules` folder doesn't exist there on the host, so this bind effectively 'hides' the node modules that we installed.

### The `node_modules` Volume Trick

There are [several](https://github.com/docker/example-voting-app/blob/7629961971ab5ca9fdfeadff52e7127bd73684a5/result-app/Dockerfile#L8) [ways](http://bitjudo.com/blog/2014/03/13/building-efficient-dockerfiles-node-dot-js/) [around](https://semaphoreci.com/community/tutorials/dockerizing-a-node-js-web-application) this problem, but I think the most elegant is to [use a volume](http://stackoverflow.com/questions/30043872/docker-compose-node-modules-not-present-in-a-volume-after-npm-install-succeeds) within the bind to contain `node_modules`. To do this, we have to add a few lines to our docker compose file:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index f3cd1c4..d72f103 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -6,3 +6,7 @@ services:
     command: echo 'ready'
     volumes:
       - .:/home/node/chat
+      - chat_node_modules:/home/node/chat/node_modules
+
+volumes:
+  chat_node_modules:
```

The `chat_node_modules:/home/node/chat` volume sets up a *named volume* [^named-volume] called `chat_node_modules` that contains the directory `/home/node/chat` in the container. The top level `volumes:` section at the end must declare all named volumes, so we add `chat_node_modules` there, too.

So, it's simple to do, but there is quite a bit going on behind the scenes to make it work:

1. During the build, `npm install` installs the dependencies (which we'll add in the next section) into `~/chat/node_modules` within the image. We'll color the files from the image blue:
   <pre style="color: blue;">
~/chat$ tree # in image
.
├── node_modules
│   ├── abbrev
...
│   └── xmlhttprequest
├── npm-shrinkwrap.json
└── package.json
   </pre>

1. When we later start a container from that image using our compose file, docker first binds the application folder from the host inside the container under `~/chat`. We'll color the files from the host red:
   <pre style="color: red;">
~/chat$ tree # in container without node_modules volume
.
├── Dockerfile
├── docker-compose.yml
├── node_modules
├── npm-shrinkwrap.json
└── package.json
   </pre>
   The bad news is that the `node_modules` in the image are hidden by the bind; inside the container, we instead see only an empty `node_modules` folder on the host.

1. However, we're not done yet. Docker next creates a *volume* that contains a copy of `~/chat/node_modules` in the image, and it mounts it in the container. This, in turn, hides the `node_modules` from the bind on the host:
   <pre style="color: red;">
~/chat$ tree # in container with node_modules volume
.
├── Dockerfile
├── docker-compose.yml<div style="color: blue;">├── node_modules
│   ├── abbrev
...
│   └── xmlhttprequest</div>├── npm-shrinkwrap.json
└── package.json
   </pre>

This gives us what we want: our source files on the host are bound inside the container, which allows for fast changes, and the dependencies are also available inside of the container, so we can use them to run the app.

(Extra credit: you might wonder where those dependency files in the volume actually get stored. In short, they live in a separate directory managed by docker on the host; see the [docker docs about volumes](https://docs.docker.com/storage/volumes/) for more info.)

### Package Installation and Shrinkwrap

So, let's rebuild the image, and we'll be ready to install packages.

```shell
$ docker-compose build
... builds and runs npm install (with no packages yet)...
```

The chat app requires express, so let's `npm install` it with `--save` to save the dependency to our `package.json` and update `package-lock.json` accordingly:

```shell
$ docker-compose run --rm chat bash
node@a342bae9c3ac:~/chat$ npm install --save express
node@a342bae9c3ac:~/chat$ exit
```

Note you don't usually have to specify the version exactly here; it's fine to just run `npm install --save express` to take whatever the latest version is, because the `package.json` and the `package-lock.json` will hold the dependency at that version next time the build runs.

The reason to use npm's [package-lock.json](https://docs.npmjs.com/files/package-lock.json) feature is that, while you can fix the versions of your direct dependencies in your `package.json`, you can't fix the versions of their dependencies, which may be quite loosely specified. This means that if you or someone else rebuilds the image at some future time, you can't guarantee (without using `package-lock.json`) that it won't pull down a different version of some indirect dependency, breaking your app. This seems to happen to me much more often than one might expect, so I advocate using `package-lock.json`. If you are familiar with ruby's excellent [bundler](http://bundler.io/) dependency manager, `npm-shrinkwrap.json` is much like `Gemfile.lock`.

Finally, it's worth noting that the `node_modules` we installed are not present on the host. There may be an empty `node_modules` folder on the host, which is a side effect of the binds and volumes we created, but the actual files live in the named `chat_node_modules` volume. If we run another shell in the `chat` container, we'll find them there:

```shell
$ ls node_modules
# nothing on the host
$ docker-compose run --rm chat bash
node@2a1dc0bcdfd7:~/chat$ ls -l node_modules/
total 196
drwxr-xr-x 2 node node 4096 Aug 24 21:33 accepts
# ... many node modules in the container
drwxr-xr-x 2 node node 4096 Aug 24 21:33 vary
```

The next time we build the image, the modules will be baked in.
```shell
$ docker-compose build
# ...
Step 6/6 : RUN npm install --quiet
 ---> Running in d869c7cd58dc
npm WARN chat@1.0.0 No description

added 50 packages from 37 contributors and audited 126 packages in 2.965s
found 0 vulnerabilities
# ...
```

Here’s the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/03-dependencies).

## Running the App

We are finally ready to install the app, so we'll copy in [the remaining source files](https://github.com/socketio/chat-example), namely `index.js` and `index.html`.

Then we'll install the `socket.io` package. At the time of writing, the chat example is only compatible with socket.io version 1, so we need to request version 1:

```sh
$ docker-compose run --rm chat bash
node@b3b1fbc1552f:~/chat$ npm install --save socket.io@1
# ...
```

In our docker compose file, we then remove our dummy `echo ready` command and instead run the chat example server. Finally, we tell Docker Compose to export 3000 in the container on the host, so we can access it in a browser:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index d72f103..2424de0 100644
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
       - .:/home/node/chat
       - chat_node_modules:/home/node/chat/node_modules
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

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/04-the-app).

## Docker for Dev and Prod

We now have our app running in development under docker compose, which is pretty cool! Before we can use this container in production, we have a few problems to solve and possible improvements to make:

- Most importantly, the container as we're building it at the moment does not actually contain the source code for the application --- it just contains the npm packaging files and dependencies. The main idea of a container is that it should contain everything needed to run the application.

- The `~/chat` application folder in the image is currently owned and writeable by the `node` user. Most applications don't need to rewrite their source files at runtime, so again applying the principle of least privilege, we shouldn't let them. There are also performance implications to writing in Docker containers, because writes will by default go through the [layer file system](https://docs.docker.com/storage/storagedriver/) inside the container, which are significantly slower than normal writes to disk. If it does need to write, the application should write to `/tmp`, which is guaranteed to be writeable, and which should be set up as a volume, so writes don't go through the layer file system.

- The image is fairly large, weighing in at 909MB according to the handy [dive](https://github.com/wagoodman/dive) image inspection tool. It's not worth obsessing over image size, but we don't want to be needlessly wasteful, either. Most of the image's heft comes from the default `node` base image, which includes a full compiler tool chain that lets us build node modules that use native code (as opposed to pure JS). We won't need that compiler tool chain at runtime, so from both a security and performance point of view, it would be better not to ship it to production.

Fortunately, Docker provide a powerful tool that helps with all of the above: multi-stage builds. The basic idea is that we can have multiple `FROM` commands in the `Dockerfile`, one per stage, and each stage can copy files from previous stages. Let's see how to set that up:

```diff
diff --git a/Dockerfile b/Dockerfile
index a32e2e5..2e99042 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -1,4 +1,4 @@
-FROM node:10.16.3
+FROM node:10.16.3 AS development

 USER node

@@ -9,3 +9,15 @@ WORKDIR /home/node/chat
 COPY --chown=node:node package.json package-lock.json ./

 RUN npm install --quiet
+
+FROM node:10.16.3-slim AS production
+
+USER node
+
+WORKDIR /srv/chat
+
+COPY --from=development --chown=root:root /home/node/chat/node_modules ./node_modules
+
+COPY . .
+
+CMD ["node", "index.js"]
```

1. Our existing `Dockerfile` steps will form the first stage, which we'll now give the name `development` by adding `AS development` to the `FROM` line at the start.

1. The new second stage starts from a `slim` node base image for the same node version, and we name it `production` for clarity. This `slim` image is also an [official node image](https://hub.docker.com/_/node) from Docker. It comes with only the operating system packages needed to run node, notably without the compiler toolchain. The `Dockerfile` now runs `npm install` in the first stage, which has the full node image at is disposal, and then just copies the resulting `node_modules` folder to the second stage, which just has to run the application. Using the slim image reduces the size from 909MB to 152MB, which is about a factor of 6 saving for relatively little effort [^alpine].

1. Again the `USER node` command tells Docker to the application as the unprivileged `node` user, rather than root.

1. This time I've chosen to install the app in `/srv` instead of in the user's home directory. This is because in production it is better to have the application's files owned by root and just readable by the `node` user. The [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/fhs.shtml) says that `/srv` is for "site-specific data which is served by this system", which seems like a good fit for a node application, and that each application should have its own folder, so I have put the files in `/srv/chat` [^srv].

1. The `COPY --from=development --chown=root:root ...` line copies in the dependencies from the `development` stage and makes them owned by root, so the unprivileged node user can read but not write them. The `COPY . .` line copies the rest of the application files from the host to the working directory in the container, namely `/srv/chat`.

1. In the development stage, the application files came from bind mounts set up with docker-compose, so I specified the command in the docker-compose file instead of the Dockerfile. In production, it makes more sense to specify the command in the container.

Now that we have our multi-stage `Dockerfile` set up, we need to tell docker-compose to use only the `development` stage rather than going through the full `Dockerfile`, which we can do with the `target` option:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index 2424de0..47c335d 100644
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

This will preserve the old behavior we had before we added multistage builds.

Finally, to make the `COPY . .` line in our new `Dockerfile` safe, we should add a `.dockerignore` file. Without it, the `COPY . .` pick up other things we don't need or want in our production image, such as our `.git` folder, any `node_modules` that are installed on the host outside of Docker, and indeed all the Docker-related files that go into building the image. Ignoring these leads to smaller images and also faster builds, because the Docker daemon does not have to work as hard to create its copy of the build context. Here's the `.dockerignore` file:
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

Now that we have distinct development and production images, let's make the development image a bit more developer-friendly by running the application under [nodemon](https://github.com/remy/nodemon) for automatic reloads within the container when we change a source file. After running
```shell
$ docker-compose run --rm chat npm install --save-dev nodemon
```
to install nodemon in the development container, we can update the compose file to run it:
```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index 47c335d..c7478a2 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -5,7 +5,9 @@ services:
     build:
       context: .
       target: development
-    command: node index.js
+    command: npx nodemon index.js
+    environment:
+      NODE_ENV: development
     ports:
       - '3000:3000'
     volumes:
```

Here we use [`npx`](https://blog.npmjs.org/post/162869356040/introducing-npx-an-npm-package-runner) to run nodemon through npm [^npm]. When we bring up the service, we should see the familiar `nodemon` output [^nodemon-rs]:

```
$ docker-compose up
Recreating docker-chat-demo_chat_1 ... done
Attaching to docker-chat-demo_chat_1
chat_1  | [nodemon] 1.19.1
chat_1  | [nodemon] to restart at any time, enter `rs`
chat_1  | [nodemon] watching: *.*
chat_1  | [nodemon] starting `node index.js`
chat_1  | listening on *:3000
```

Finally, it's worth noting that with the Dockerfile above the dev dependencies will be included in the production image. It is possible to break out another stage to avoid this, but I would argue this is not necessarily a bad thing, because it improves dev-prod parity, and it means we can run the tests in our production container as part of CI. As some [wise people once said](http://llis.nasa.gov/lesson/1196), 'test as you fly, fly as you test.' Speaking of which, we don't have any tests, but it's easy enough to run them when you do:

```shell
$ docker-compose run --rm chat npm test

> chat@1.0.0 test /home/node/chat
> echo "Error: no test specified" && exit 1

Error: no test specified
npm ERR! Test failed.  See above for more details.
```

Here's the [final code on github](https://github.com/jdleesmiller/docker-chat-demo).

## Conclusion

We've taken an app and got it running in development and production entirely within Docker. Woohoo!

We had to jump through some hoops to bootstrap a node environment without installing anything on the host, but I hope it was edifying, and you only have to do it once.

Node / npm's habit of putting dependencies in a subfolder makes our lives a little bit more complicated than other solutions, such as ruby's bundler, that install your dependencies somewhere else, but we were able to work around that fairly easily with the 'nested volume' trick.

We finished this article with a note about testing node.js services in Docker, and that's where I'll pick things up in my next article.

<p>&nbsp;</p>
---
<p>&nbsp;</p>

If you've read this far, you should [follow me on twitter](https://twitter.com/jdleesmiller), or maybe even apply to work at [Overleaf](https://www.overleaf.com). `:)`

<p>&nbsp;</p>
---
<p>&nbsp;</p>

# Appendix A: Working around UID/GID Mismatches on Linux

TODO

```Dockerfile
RUN groupmod -g 500 node && usermod -u 500 node
```

# Footnotes

[^compose-file-v2]: Both the 2.x and 3.x versions of the Docker Compose file format are still being actively developed. The main benefit of the 3.x series is that it is cross-compatible between single-node applications running on Docker Compose and multi-node applications running on Docker Swarm. In order to be compatible, version 3 drops some useful features from version 2. If you are only interested in Docker Compose, you might prefer to stick with the [latest 2.x format](https://docs.docker.com/compose/compose-file/compose-file-v2/).

[^named-volume]: We could instead use an *anonymous volume* to contain the modules, just by omitting the name:
    ```diff
    diff --git a/docker-compose.yml b/docker-compose.yml
    index f3cd1c4..298db26 100644
    --- a/docker-compose.yml
    +++ b/docker-compose.yml
    @@ -6,3 +6,4 @@ services:
         command: echo 'ready'
         volumes:
           - .:/home/node/chat
    +      - /home/node/chat/node_modules
    ```
    That would be shorter, but it is very easy to forget to clean up anonymous volumes, which leads to a profusion of anonymous modules with no indication which container they came from. You can still clean them up with `docker system prune`, but that is a bit of 'sledge hammer to crack a nut'. The named volumes approach is a bit more verbose but also more transparent.

[^no-build]: The eagle eyed reader may have noticed that we don't have to `docker-compose build` to get the dependencies installed before `docker-compose up`. This is because it is running with the node modules in the `chat_node_modules` named volume. The next time we do a build, npm will install the dependencies from scratch into the image. If you ever find yourself in a situation where you want to get rid of the named volume and start from scratch, you can run `docker volume list` to get a list. The name of the volume will depend on your docker compose project. In my case, the volume of interest is `docker-chat-demo_chat_node_modules` so we can remove it with `docker-compose rm -v chat` then `docker volume rm docker-chat-demo_chat_node_modules`.

[^alpine]: Docker also provides an official `alpine` image variant that is even smaller. However, these size savings come in part from using a completely different [`libc`](https://en.wikipedia.org/wiki/C_standard_library) and package manager than the Debian-based images. Unless you are deploying to embedded systems where space is at a premium, the complexities that may arise due to these differences may not be worth it, especially when the Debian-based slim images already offer substantial savings.

[^srv]: Fundamentally, it doesn't matter where the files go in the container. `/opt` would be another very reasonable choice. Or we could just keep them under `/home/node/chat`, but then it would be a bit odd in production to have that folder owned by root.

[^signals]: You might notice that it takes about 10s to stop. This is because the socket.io chat example does not correctly handle the `SIGTERM` signal, which Docker sends it when it's time to stop, to perform a graceful shutdown. Extra credit: add this code to the end of `index.js`:
    ```js
    process.on('SIGTERM', function() {
      io.close();
      Object.values(io.of('/').connected).forEach(s => s.disconnect(true));
    });
    ```
    then rebuild the production image and try to run and `docker stop` the container again. It should disconnect any clients and stop promptly after that change.

[^npm]: Using npm to run processes in containers is sometimes discouraged, but I think that advice is out of date. Older versions of npm did have problems [handling signals](https://github.com/npm/npm/pull/10868) needed to cleanly shut down processes, but this should be fixed in recent versions. If your containers always seem to take 10s to shut down, it's likely that they are not listening for the `SIGTERM` signal to initiate a graceful shutdown; see [^signals]. Running the process through `npm` does create some overhead, namely an additional node process, so you may want to avoid it in production, but in development it is usually fine.

[^nodemon-rs]: You may notice that nodemon says that typing `rs` will restart it. That won't work if we use `docker-compose up` to bring up the service, because our terminal is not connected to nodemon's standard input when we do that. If we run `docker-compose run --rm chat` instead, `rs` should work as usual; this can be useful when you're working on one service in particular.
