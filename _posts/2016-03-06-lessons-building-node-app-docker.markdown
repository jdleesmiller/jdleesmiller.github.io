---
layout: post
title: "Lessons from Building a Node App in Docker"
date: 2016-03-06 19:54:56 +0000
categories: articles
---

**Updates**

**2016-04-22** There was some lively [discussion about this article on Hacker News](https://news.ycombinator.com/item?id=11545975).

**2016-07-14** This article has been [translated into Japanese](http://postd.cc/lessons-building-node-app-docker/)!

---

&nbsp;

Here are some tips and tricks that I learned the hard way when developing and deploying web applications written for [node.js](https://nodejs.org) using [Docker](https://www.docker.com).

In this tutorial article, we'll set up the [socket.io chat example](http://socket.io/get-started/chat/) in docker, from scratch to production-ready, so hopefully you can learn these lessons the easy way. In particular, we'll see how to:

  * Actually get started bootstrapping a node application with docker.
  * Not run everything as root (bad!).
  * Use binds to keep your test-edit-reload cycle short in development.
  * Manage `node_modules` in a container for fast rebuilds (there's a trick to this).
  * Ensure repeatable builds with [npm shrinkwrap](https://docs.npmjs.com/cli/shrinkwrap).
  * Share a `Dockerfile` between development and production.

This tutorial assumes you already have some familiarity with Docker and node.js. If you'd like a gentle intro to docker first, you can <a href="http://jdlm.info/ds-docker-demo/" target="_blank">try my slides about docker</a> (<a href="https://news.ycombinator.com/item?id=8630451" target="_blank">discussion on hacker news</a>) or try one of the many, many other docker intros out there.

## Getting Started

We're going to set things up from scratch. The final code is available [on github here](https://github.com/jdleesmiller/docker-chat-demo), and there are tags for each step along the way. [Here's the code for the first step](https://github.com/jdleesmiller/docker-chat-demo/tree/01-bootstrapping), in case you'd like to follow along.

Without docker, we'd start by installing node and any other dependencies on the host and running `npm init` to create a new package. There's nothing stopping us from doing that here, but we'll learn more if we use docker from the start. (And of course the whole point of using docker is that you don't have to install things on the host.) Instead, we'll start by creating a "bootstrapping container" that has node installed, and we'll use it to set up the npm package for the application.

We'll need to write two files, a `Dockerfile` and a `docker-compose.yml`, to which we'll add more later on. Let's start with the bootstrapping `Dockerfile`:

```Dockerfile
FROM node:4.3.2

RUN useradd --user-group --create-home --shell /bin/false app &&\
  npm install --global npm@3.7.5

ENV HOME=/home/app

USER app
WORKDIR $HOME/chat
```

This file is relatively short, but there already some important points:

1. We start from the official docker image for the latest long term support (LTS) release, at time of writing. I prefer to name a specific version, rather than one of the 'floating' tags like `node:argon` or `node:latest`, so that if you or someone else builds this image on a different machine, they will get the same version, rather than risking an accidental upgrade and attendant head-scratching.

1. We create an unprivileged user, prosaically called `app`, to run the app inside the container. If you don't do this, then the process inside the container will run as **root**, which is against security best practices and [principles](https://en.wikipedia.org/wiki/Principle_of_least_privilege). Many docker tutorials skip this step for simplicity, and we will have to do some extra work to make things work, but I think it's very important.

1. Install a more recent version of NPM. This isn't strictly necessary, but npm has improved a lot recently, and in particular `npm shrinkwrap` support is a lot better; more on shrinkwrap later. Again, I think it's best to specify an exact version in the Dockerfile, to avoid accidental upgrades on later builds.

1. Finally, note that we chain two shell commands together in a single `RUN` command. This reduces the number of layers in the resulting image. In this example, it really doesn't matter very much, but it is a [good habit](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/) not to use more layers than you need. It can save a lot of disk space and download time if you e.g. download a package, unzip it, build it, install it, and then clean up in one step, rather than saving layers with all of the intermediate files for each step.

Now let's move on to the bootstrapping compose file, `docker-compose.yml`:

```yaml
chat:
  build: .
  command: echo 'ready'
  volumes:
    - .:/home/app/chat
```

It defines a single service, built from the `Dockerfile`. All it does for now is to echo `ready` and exit. The volume line, `.:/home/app/chat`, tells docker to mount the application folder `.` on the host to the `/home/app/chat` folder inside the container, so that changes we'll make to source files on the host will be automatically reflected inside the container, and vice versa. This is very important for keeping your test-edit-reload cycles as short as possible in development. It will, however, create some issues with how npm installs dependencies, which we'll come back to.

(**Update:** I should also mention that in order to use the volume line to mount the application folder from the host in the container, the uids (Linux user identifiers) must be the same on the host and in the container. Particularly if you use a newer node image, you may find that the uid does not match. See [https://github.com/jdleesmiller/docker-chat-demo/issues/8](this issue) for more info.)

For now, however, we’re good to go. When we run docker-compose up, docker will create an image with node set up as specified in the `Dockerfile`, and it will start a container with that image and run the echo command, which shows that everything is set up OK.

```shell
$ docker-compose up
Building chat
Step 1 : FROM node:4.3.2
 ---> 3538b8c69182
...
lots of build output
...
Successfully built 1aaca0ac5d19
Creating dockerchatdemo_chat_1
Attaching to dockerchatdemo_chat_1
chat_1 | ready
dockerchatdemo_chat_1 exited with code 0
```

Now we can run an interactive shell in a container created from the same image and use it to set up the initial package files:

```shell
$ docker-compose run --rm chat /bin/bash
app@e93024da77fb:~/chat$ npm init --yes
... writes package.json ...
app@e93024da77fb:~/chat$ npm shrinkwrap
... writes npm-shrinkwrap.json ...
app@e93024da77fb:~/chat$ exit
```

And here they are on the host, ready for us to commit to version control:

```shell
$ tree
.
├── Dockerfile
├── docker-compose.yml
├── npm-shrinkwrap.json
└── package.json
```

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/02-bootstrapped).

## Installing Dependencies

Next up on our list is to install the app's dependencies. We want these dependencies to be installed inside the container via the `Dockerfile`, so when we run `docker-compose up` for the first time, the app is ready to go.

In order to do this, we need to run `npm install` in the `Dockerfile`, and, before we do that, we need to get the `package.json` and `npm-shrinkwrap.json` files that it reads into the image. Here's what the change looks like:

```diff
diff --git a/Dockerfile b/Dockerfile
index c2afee0..9cfe17c 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -5,5 +5,9 @@ RUN useradd --user-group --create-home --shell /bin/false app &&\

 ENV HOME=/home/app

+COPY package.json npm-shrinkwrap.json $HOME/chat/
+RUN chown -R app:app $HOME/*
+
 USER app
 WORKDIR $HOME/chat
+RUN npm install
```

Again, it's a pretty small change, but there are some important points:

1. We could `COPY` the whole application folder on the host into `$HOME/chat`, rather than just the packaging files, but we'll see later that we can save some time on our docker builds by only copying in what we need at this point, and copying in the rest after we run `npm install`. This takes better advantage of `docker build`'s layer caching.

1. Files copied into the container with the `COPY` command end up being owned by root inside of the container, which means that our unprivileged `app` user can't read or write them, which it will not like. So, we simply `chown` them to `app` after copying. (It would be nice if we could move the `COPY` after the `USER app` step, and the files would be copied as the `app` user, but that is [not (yet) the case](https://github.com/docker/docker/issues/6119).)

1. Finally, we added a step at the end to run `npm install`. This will run as the `app` user and install the dependencies in `$HOME/chat/node_modules` inside the container. (Extra credit: add `npm cache clean` to remove the tar files that npm downloads during the install; they won't help if we rebuild the image, so they just take up space.)

That last point causes some trouble when we use the image in development, because we bind `$HOME/chat` inside the container to the application folder on the host. Unfortunately, the `node_modules` folder doesn't exist there on the host, so this bind effectively 'hides' the node modules that we installed.

### The `node_modules` Volume Trick

There are [several](https://github.com/docker/example-voting-app/blob/7629961971ab5ca9fdfeadff52e7127bd73684a5/result-app/Dockerfile#L8) [ways](http://bitjudo.com/blog/2014/03/13/building-efficient-dockerfiles-node-dot-js/) [around](https://semaphoreci.com/community/tutorials/dockerizing-a-node-js-web-application) this problem, but I think the most elegant is to [use a volume](http://stackoverflow.com/questions/30043872/docker-compose-node-modules-not-present-in-a-volume-after-npm-install-succeeds) within the bind to contain `node_modules`. To do this, we just have to add one line to the end of our docker compose file:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index 9e0b012..9ac21d6 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -3,3 +3,4 @@ chat:
   command: echo 'ready'
   volumes:
     - .:/home/app/chat
+    - /home/app/chat/node_modules
```

So, it's simple to do, but there is quite a bit going on behind the scenes to make it work:

1. During the build, `npm install` installs the dependencies (which we'll add in the next section) into `$HOME/chat/node_modules` within the image. We'll color the files from the image blue:
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

1. When we later start a container from that image using our compose file, docker first binds the application folder from the host inside the container under `$HOME/chat`. We'll color the files from the host red:
   <pre style="color: red;">
~/chat$ tree # in container without node_modules volume
.
├── Dockerfile
├── docker-compose.yml
├── node_modules
├── npm-shrinkwrap.json
└── package.json
   </pre>
   The bad news is that the `node_modules` in the image are hidden by the bind; inside the container, we instead see only the empty `node_modules` folder on the host.

1. However, we're not done yet. Docker next creates a *volume* that contains a copy of `$HOME/chat/node_modules` in the image, and it mounts it in the container. This, in turn, hides the `node_modules` from the bind on the host:
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

(Extra credit: you might wonder where those dependency files in the volume actually get stored. In short, they live in a separate directory managed by docker on the host; see the [docker docs about volumes](https://docs.docker.com/engine/userguide/containers/dockervolumes/) for more info.)

### Package Installation and Shrinkwrap

So, let's rebuild the image, and we'll be ready to install packages.

```shell
$ docker-compose build
... builds and runs npm install (with no packages yet)...
```

The chat app requires express at version 4.10.2, so let's `npm install` it with `--save` to save the dependency to our `package.json` and update `npm-shrinkwrap.json` accordingly:

```shell
$ docker-compose run --rm chat /bin/bash
app@9d800b7e3f6f:~/chat$ npm install --save express@4.10.2
app@9d800b7e3f6f:~/chat$ exit
```

Note you don't usually have to specify the version exactly here; it's fine to just run `npm install --save express` to take whatever the latest version is, because the `package.json` and the shrinkwrap will hold the dependency at that version next time the build runs.

The reason to use npm's [shrinkwrap](https://docs.npmjs.com/cli/shrinkwrap) feature is that, while you can fix the versions of your direct dependencies in your `package.json`, you can't fix the versions of their dependencies, which may be quite loosely specified. This means that if you or someone else rebuilds the image at some future time, you can't guarantee (without using shrinkwrap) that it won't pull down a different version of some indirect dependency, breaking your app. This seems to happen to me much more often than one might expect, so I advocate using shrinkwrap. If you are familiar with ruby's excellent [bundler](http://bundler.io/) dependency manager, `npm-shrinkwrap.json` is much like `Gemfile.lock`.

Finally, it's worth noting that because we ran that container as a one-off `docker-compose run`, the actual modules we installed have vanished. But, next time we run a docker build, docker will detect that the `package.json` and the shrinkwrap have changed, and that it has to rerun `npm install`, which is the important thing. The packages we need will then be installed in the image:

```shell
$ docker-compose build
... lots of npm install output
$ docker-compose run --rm chat /bin/bash
app@912d123f3cea:~/chat$ ls node_modules/
accepts              cookie-signature  depd ...
...
app@912d123f3cea:~/chat$ exit
```

Here’s the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/03-dependencies).

## Running the App

We are finally ready to install the app, so we'll copy in [the remaining source files](https://github.com/rauchg/chat-example), namely `index.js` and `index.html`. Then we'll install the `socket.io` package, using `npm install --save` as we did in the previous section.

In our `Dockerfile`, we can now tell docker what command to run when starting a container using the image, namely `node index.js`. Then we remove the dummy command from our docker compose file so docker will run that command from the `Dockerfile`. Finally, we tell docker compose to expose port 3000 in the container on the host, so we can access it in a browser:

```diff
diff --git a/Dockerfile b/Dockerfile
index 9cfe17c..e2abdfc 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -11,3 +11,5 @@ RUN chown -R app:app $HOME/*
 USER app
 WORKDIR $HOME/chat
 RUN npm install
+
+CMD ["node", "index.js"]
diff --git a/docker-compose.yml b/docker-compose.yml
index 9ac21d6..e7bd11e 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -1,6 +1,7 @@
 chat:
   build: .
-  command: echo 'ready'
+  ports:
+    - '3000:3000'
   volumes:
     - .:/home/app/chat
     - /home/app/chat/node_modules
```

Then we just need a final build, and we're ready to run with `docker-compose up`:

```shell
$ docker-compose build
... lots of build output
$ docker-compose up
Recreating dockerchatdemo_chat_1
Attaching to dockerchatdemo_chat_1
chat_1 | listening on *:3000
```

Then (after, if you're on a Mac, some fiddling to get port 3000 forwarded from the boot2docker VM to the host) you can see it running on `http://localhost:3000`.

![Docker chat demo working!](/assets/docker_chat_demo/chat.png)

Here's the [resulting code on github](https://github.com/jdleesmiller/docker-chat-demo/tree/04-the-app).

## Docker for Dev and Prod

We now have our app running in development under docker compose, which is pretty cool! Now let's look at some possible next steps.

If we want to deploy our application image to production, we clearly want to build the application source into said image. To do this, we just copy the application folder into the container after the `npm install` --- that way docker will only rerun the `npm install` step if `package.json` or `npm-shrinkwrap.json` have changed, not when we just change a source file. Note that we do again have to work around the problem with `COPY` copying the files as root:

```diff
diff --git a/Dockerfile b/Dockerfile
index e2abdfc..68d0ad2 100644
--- a/Dockerfile
+++ b/Dockerfile
@@ -12,4 +12,9 @@ USER app
 WORKDIR $HOME/chat
 RUN npm install

+USER root
+COPY . $HOME/chat
+RUN chown -R app:app $HOME/*
+USER app
+
 CMD ["node", "index.js"]
```

Now we can run the container standalone, without any volumes from the host. Docker compose lets you [compose multiple compose](https://docs.docker.com/compose/extends/) files to avoid code duplication in compose files, but since our app is very simple, we'll just add a second compose file, `docker-compose.prod.yml`, that runs the application in a production environment:

```yaml
chat:
  build: .
  environment:
    NODE_ENV: production
  ports:
    - '3000:3000'
```

We can run the application in 'production mode' with:

```shell
$ docker-compose -f docker-compose.prod.yml up
Recreating dockerchatdemo_chat_1
Attaching to dockerchatdemo_chat_1
chat_1 | listening on *:3000
```

We can similarly specialize the container for development, for example by running the application under [nodemon](https://github.com/remy/nodemon) for automatic reloads within the container when we change a source file. (Note: if you're on a Mac with docker-machine, this doesn't fully work yet, because virtualbox shared folders don't work with inotify; hopefully this situation will improve soon.) After running `npm install --save-dev nodemon` in the container and rebuilding, we can override the default production command, `node index.js`, in the container with a setting more suitable for development:

```diff
diff --git a/docker-compose.yml b/docker-compose.yml
index e7bd11e..d031130 100644
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -1,5 +1,8 @@
 chat:
   build: .
+  command: node_modules/.bin/nodemon index.js
+  environment:
+    NODE_ENV: development
   ports:
     - '3000:3000'
   volumes:
```

Note that we have to give the full path to `nodemon`, because it is installed as an npm dependency and so is not on the path. We could set up an npm script to run `nodemon`, but I've had problems with that approach. Containers running npm scripts tend to take 10s to shut down (the default timeout), because `npm` does not forward the `TERM` signal from docker to the actual process. It therefore seems better to just run the command directly. (**Update:** This [should be fixed](https://github.com/npm/npm/pull/10868) in npm 3.8.1+, so you should now be able to use npm scripts in containers!)

```
$ docker-compose up
Removing dockerchatdemo_chat_1
Recreating 3aec328ebc_dockerchatdemo_chat_1
Attaching to dockerchatdemo_chat_1
chat_1 | [nodemon] 1.9.1
chat_1 | [nodemon] to restart at any time, enter `rs`
chat_1 | [nodemon] watching: *.*
chat_1 | [nodemon] starting `node index.js`
chat_1 | listening on *:3000
```

Specializing the docker compose files lets us use the same Dockerfile and image across multiple environments. It's not maximally space-efficient, because we'll install dev dependencies in production, but I think that's a small price to pay for better dev-prod parity. As some [wise people once said](http://llis.nasa.gov/lesson/1196), 'test as you fly, fly as you test.' Speaking of which, we don't have any tests, but it's easy enough to run them when you do:

```shell
$ docker-compose run --rm chat /bin/bash -c 'npm test'
npm info it worked if it ends with ok
npm info using npm@3.7.5
npm info using node@v4.3.2
npm info lifecycle chat@1.0.0~pretest: chat@1.0.0
npm info lifecycle chat@1.0.0~test: chat@1.0.0

> chat@1.0.0 test /home/app/chat
> echo "Error: no test specified" && exit 1

Error: no test specified
npm info lifecycle chat@1.0.0~test: Failed to exec test script
npm ERR! Test failed.  See above for more details.
```
(Extra credit: run `npm` with `--silent` to get rid of that extra output.)

Here's the [final code on github](https://github.com/jdleesmiller/docker-chat-demo).

## Conclusion

- We've taken an app and got it running in development and production entirely within docker. Woohoo!

- We had to jump through some hoops to bootstrap a node environment without installing anything on the host, but I hope it was edifying, and you only have to do it once.

- Node / npm's habit of putting dependencies in a subfolder makes our lives a little bit more complicated than other solutions, such as ruby's bundler, that install your dependencies somewhere else, but we were able to work around that fairly easily with the 'nested volume' trick.

- This is still a pretty simple application, so there's plenty of scope for further articles, perhaps along the lines of:

  - Structuring projects with multiple services, such as an API, a worker and a static front end. A single large repo seems to be easier to manage than splitting each service into its own repo, but it introduces some complexities of its own.

  - Using `npm link` to reuse code in packages shared between services.

  - Using docker to replace other log management and process monitoring tools in production.

  - State and configuration management, including database migrations.

If you've read this far, perhaps you should [follow me on twitter](https://twitter.com/jdleesmiller), or even apply to work at [Overleaf](https://www.overleaf.com). `:)`

<p>&nbsp;</p>
---
<p>&nbsp;</p>

Thanks to [Michael Mazour](https://twitter.com/mmazour) and [John Hammersley](https://twitter.com/DrHammersley) for reviewing drafts of this article.
