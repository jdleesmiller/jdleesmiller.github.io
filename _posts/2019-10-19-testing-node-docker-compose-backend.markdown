---
layout: post
title: "Testing with Node and Docker Compose, Part 1: On the Backend"
date: 2019-10-19 22:00:00 +0000
categories: articles
image: /assets/todo-demo/todo-demo.gif
description: Tutorial article about testing node.js applications under Docker and Docker Compose. Part 1 focuses on testing a single backend API service.
---

My [last post](/articles/2019/09/06/lessons-building-node-app-docker.html) covered the basics of how to get a node.js application running in Docker. This post is the first in a short series about automated testing in node.js web applications with Docker.

It boils down to running `npm test` in a Docker container, which may not seem like it should require multiple blog posts! However, as an application gets more complicated and requires more kinds of testing, such as frontend testing and end-to-end testing across multiple services, getting to `npm test` can be nontrivial. Fortunately, Docker and Docker Compose provide tools that can help.

To illustrate, we'll build and test an example application: a small TODO list manager. Here's what it will look like when finished, at the end of the series:

<p align="center">
  <a href="/assets/todo-demo/todo-demo.gif"><img src="/assets/todo-demo/todo-demo.gif" alt="Create some todos, search, and complete them" style="max-width: 448px;"></a>
</p>

In this post, we'll start with the backend, which is a small node.js service that provides a RESTful API for managing the task list. In particular, we'll:

- cover some (opinionated) background on web application testing,
- set up a node.js service and a database for development with Docker Compose,
- write shell scripts to automate some repetitive `docker-compose` commands,
- see how to set up and connect to separate databases for development and test, and
- finally, run `npm test` in the container!

Subsequent posts will extend the approach developed here to include frontend and end-to-end testing, and then to multiple services. The Compose setup in this post is pretty standard and provides the foundation from which we'll build up to using some more advanced features as the application grows.

The code is [available on GitHub](https://github.com/jdleesmiller/todo-demo), and each post in the series has a git tag that marks the [corresponding code](https://github.com/jdleesmiller/todo-demo/tree/todo-backend/todo).

## The TODO List Manager Backend

Let's start with a quick tour of the service we'll be developing and testing. It uses [PostgreSQL](https://www.postgresql.org/) for the datastore and [Express](https://expressjs.com/) for the web server. For convenient database access, it uses [knex.js](https://knexjs.org) with [Objection.js](https://vincit.github.io/objection.js/) as the object-relational mapping layer.

It has just one model: a `Task` on the TODO list. Each task has an identifier and a description, which can't be null and must have a sensible length. Here's the code:

#### [`src/task.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/src/task.js)
```js
const { Model } = require('objection')

require('./knex') // ensure database connections are set up

class Task extends Model {
  static get tableName() {
    return 'tasks'
  }

  static get jsonSchema() {
    return {
      type: 'object',
      required: ['description'],

      properties: {
        id: { type: 'integer' },
        description: { type: 'string', minLength: 1, maxLength: 255 }
      }
    }
  }
}

module.exports = Task
```

The service exposes a [RESTful](https://en.wikipedia.org/wiki/Representational_state_transfer) API for managing the tasks, which is implemented in the usual way:

#### [`src/app.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/src/app.js)
```js
const bodyParser = require('body-parser')
const express = require('express')

const Task = require('./task')

const app = express()

app.use(bodyParser.json())

// Is the service up?
app.get('/status', (req, res) => res.sendStatus(204))

// List tasks.
app.get('/api/tasks', async (req, res, next) => {
  try {
    const tasks = await Task.query().orderBy('id')
    res.json({ tasks })
  } catch (error) {
    next(error)
  }
})

// Create a new task.
app.post('/api/tasks', async (req, res, next) => {
  try {
    const task = await Task.query().insert({
      description: req.body.description
    })
    res.json({ task })
  } catch (error) {
    if (error instanceof Task.ValidationError) {
      res.status(400).json({ error: { message: error.message } })
      return
    }
    next(error)
  }
})

// Check the id route param looks like a valid id.
app.param('id', (req, res, next, id) => {
  if (/^\d+$/.test(req.params.id)) return next()
  res.sendStatus(404)
})

// Complete a task (by deleting it from the task list).
app.delete('/api/tasks/:id', async (req, res, next) => {
  try {
    await Task.query().deleteById(req.params.id)
    res.sendStatus(204)
  } catch (error) {
    next(error)
  }
})

module.exports = app
```

The API endpoints are relatively thin wrappers around the ORM, because there's not much logic in a TODO list app, but we'll still find some worthwhile things to test.

Behind the scenes, there is also some boilerplate for database [connection strings](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/knexfile.js), [database access](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/src/knex.js), [database migrations](https://github.com/jdleesmiller/todo-demo/tree/todo-backend/todo/migrations), and [running the server](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/server.js).

### Dockerfile and Compose for Development

Next let's see how to get the service running in development. I've followed the approach in [my previous post](/articles/2019/09/06/lessons-building-node-app-docker.html) to set up [`Dockerfile`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/Dockerfile) that handles getting node and its dependencies installed, so here let's focus on the Compose file:

#### [`docker-compose.yml`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/docker-compose.yml)
```yml
version: '3.7'

services:
  todo:
    build:
      context: .
      target: development
    command: npx nodemon server.js
    depends_on:
      - postgres
    environment:
      PORT: 8080
    ports:
      - '8080:8080'
    volumes:
      - .:/srv/todo
      - todo_node_modules:/srv/todo/node_modules

  postgres:
    image: postgres:12

volumes:
  todo_node_modules:
```

It's short but fairly dense. Let's break it down:

- The Compose file defines two services, our `todo` API service and its database, `postgres`.
- The `todo` service is built from the current directory, using the `development` stage of the multi-stage Dockerfile, like [in my last post](/articles/2019/09/06/lessons-building-node-app-docker.html#docker-for-dev-and-prod).
- The `command` runs the service in the container under [nodemon](https://nodemon.io/), so it will restart automatically when the code changes in development.
- The `todo` service `depends_on` the `postgres` database; this just ensures that the database is started whenever the `todo` service starts.
- The `todo` service [uses the `PORT` environment variable](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/server.js#L5) to decide what port to listen on in the container, here `8080`. The `ports` key then tells compose to expose port `8080` in the container on port `8080` on the host, so we can access the service on `http://localhost:8080`.
- The `volumes` are set up to allow us to bind the service's source files on the host into the container for fast edit-reload-test cycles, like in [my last post](/articles/2019/09/06/lessons-building-node-app-docker.html#the-node_modules-volume-trick).
- There's not much to the `postgres` service, because we're using it as it comes. It's worth noting that the image is fixed to version 12, which is the latest at the time of writing. It's a good idea to fix a version (at least a [major version](https://www.postgresql.org/support/versioning/)) to avoid accidental upgrades.

### Development Helper Scripts

Now that Compose is set up, let's see how to use it. While not strictly speaking required, it is often helpful to write some [shell scripts](https://github.com/jdleesmiller/todo-demo/tree/todo-backend/todo/bin) to automate common tasks. This saves on typing and helps with consistency. The most interesting script is the `bin/up` script, which handles the initial setup and can also be safely re-run to make sure you are up to date after pulling in remote changes:

#### [`bin/up`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/bin/up)

```sh
#!/usr/bin/env bash

set -e

docker-compose up -d postgres

WAIT_FOR_PG_ISREADY="while ! pg_isready --quiet; do sleep 1; done;"
docker-compose exec postgres bash -c "$WAIT_FOR_PG_ISREADY"

for ENV in development test
do
  # Create database for this environment if it doesn't already exist.
  docker-compose exec postgres \
    su - postgres -c "psql $ENV -c '' || createdb $ENV"

  # Run migrations in this environment.
  docker-compose run --rm -e NODE_ENV=$ENV todo npx knex migrate:latest
done

docker-compose up -d
```

Taking it from the top:

- The `set -e` tells the script to abort on the first error, instead of continuing and getting into even deeper trouble. All shell scripts should start with this.

- It starts up the database and then runs the built-in postgres [`pg_isready`](https://www.postgresql.org/docs/current/app-pg-isready.html) utility in a loop, waiting until postgres finishes starting up (which is usually pretty quick, but not instant). If we didn't do this, subsequent commands that need the database might fail sporadically.

- Then it creates two databases, one called `development` and one called `test` and runs the [database migrations](https://en.wikipedia.org/wiki/Schema_migration) in each one. The application [uses the connection string for the appropriate database](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/knexfile.js) depending on what `NODE_ENV` it is running in. More on this later.

- Finally it brings up the rest of the application with `up -d`, which runs it detached, in the background.

The application is just an API at this point, so here's what it looks like when exercised with `curl` on `localhost:8080` --- an interface that only a developer could love:

```sh
# Create a task 'foo'.
$ curl --header 'Content-Type: application/json' \
  --data '{"description": "foo"}' \
  http://localhost:8080/api/tasks
{"task":{"description":"foo","id":1}}

# List the tasks, which now include 'foo'.
$ curl http://localhost:8080/api/tasks
{"tasks":[{"id":1,"description":"foo"}]}

# Complete task 'foo' by its ID.
$ curl -X DELETE http://localhost:8080/api/tasks/1
```

## The Tests

Now that we've seen the service, let's look at the tests. I've chosen two kinds of tests for the example service, *model tests* and *integration tests*. These terms are borrowed from [Ruby on Rails](https://guides.rubyonrails.org/testing.html), which I think encourages an approach to testing that is sound for many kinds of web applications.

Model tests test the 'model' layer of the [Model-View-Controller](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller) (MVC) architecture, which most web applications follow to at least some degree. The model layer contains the application's core business logic. The controllers are responsible for translating between the model layer and the view layer, which comprises, for most web applications, HTML or JSON responses to HTTP requests. Integration tests test that the models, controllers and views work together. In diagram form:

<p align="center">
  <a href="/assets/todo-demo/todo-backend-tests.svg"><img src="/assets/todo-demo/todo-backend-tests.svg" alt="From left to right, a database, then a service comprising models, controllers and views. Model tests encompass the database and the models. Integration tests encompass the database, models, controllers and views."></a>
</p>

Note that both model and integration tests have access to the database; the database is not mocked, because it is an essential part of the application. There are certainly cases where mocks are the right tool for the job, but I think the primary database is rarely one of them. I've included [an appendix](#appendix-views-on-testing) with some further discussion on this point.

#### Model Tests

So, let's see some examples of model tests. The example app doesn't have much in the way of core business logic, so these particular model tests border on trivial. However, they illustrate at least one thing that model tests often do: they exercise the `Task` model to check that some valid data can be inserted and some invalid data can't be:

#### [`test/model/task.test.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/test/model/task.test.js)
```js
const assert = require('assert')

const cleanup = require('../support/cleanup')

const Task = require('../../src/task')

describe('Task', function() {
  beforeEach(cleanup.database)

  it('can be created with a valid description', async function() {
    const description = 'a'.repeat(255)
    const task = await Task.query().insert({ description })
    assert.strictEqual(task.description, description)
  })

  it('must have a description', async function() {
    try {
      await Task.query().insert({
        description: ''
      })
      assert.fail()
    } catch (error) {
      assert(error instanceof Task.ValidationError)
      assert(/should NOT be shorter than 1 characters/.test(error.message))
    }
  })

  it('must not have an overly long description', async function() {
    try {
      await Task.query().insert({
        description: 'a'.repeat(1000)
      })
      assert.fail()
    } catch (error) {
      assert(error instanceof Task.ValidationError)
      assert(/should NOT be longer than 255 characters/.test(error.message))
    }
  })
})
```

A few remarks:

- The tests are written with [mocha](https://mochajs.org/) and the built-in [node assertions](https://nodejs.org/api/assert.html). (It is usually worthwhile to use a library such as `chai` for more kinds of assertions, but I didn't want to overload the example app with tons of libraries, and node's `assert` does the job.)

- The `cleanup.database` hook at the top is a [helper function](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/test/support/cleanup.js) I wrote to clear out the database before each test. Compared with cleaning up more selectively, this is a brute force approach, but it does help avoid flakey tests by making sure each test starts with a clean slate.

- These model tests are for the `Task` model, which is a model in the ORM sense of the word. However, model tests can test other kinds of code that aren't coupled to the ORM and database, too. If your application affords some pure functions (woo hoo!) or plain objects (also good!), you can still test those in model tests. Just omit the `cleanup.database` hook.

Technically, the main thing that distinguishes a model test from an integration test is that it doesn't require spinning up or interacting with the express app. The model layer in MVC should be independent from the controller and view layers where possible --- it should not care if it's running in a background job or a service using websockets instead of plain HTTP. If it does, parts of it probably belong in the controller or view layer, where they will be easier to test with integration tests.

#### Integration tests

That brings us to integration tests, in which we do start up the express app and test it primarily by making HTTP requests. I wrote another [test helper](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/test/support/test-server.js) to start the express application in a global mocha `before` hook, so it starts once for the whole test suite. The helper also puts a `testClient` object on mocha's `this` with convenience methods for making requests against the app, such as `this.testClient.post`. Here are some integration tests:

#### [`test/integration/todo.test.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/test/integration/todo.test.js)
```js
const assert = require('assert')

const cleanup = require('../support/cleanup')

const Task = require('../../src/task')

// Ensure the global test server is started, for this.testClient.
require('../support/test-server')

describe('todo', function() {
  beforeEach(cleanup.database)

  describe('with existing tasks', function() {
    let exampleTasks
    beforeEach(async function() {
      exampleTasks = await Task.query().insert(
        ['foo', 'bar'].map(description => ({ description }))
      )
    })

    it('lists the tasks', async function() {
      const response = await this.testClient.get('/api/tasks')
      assert(response.ok)
      const body = await response.json()
      assert.strictEqual(body.tasks.length, 2)
      assert.strictEqual(body.tasks[0].description, 'foo')
    })

    it('completes a task', async function() {
      const response = await this.testClient.delete(
        `/api/tasks/${exampleTasks[0].id}`
      )
      assert.strictEqual(response.status, 204)

      const remainingTasks = await Task.query()
      assert.strictEqual(remainingTasks.length, 1)
      assert.strictEqual(remainingTasks[0].id, exampleTasks[1].id)
    })
  })

  it('creates a task', async function() {
    const response = await this.testClient.post('/api/tasks', {
      description: 'foo'
    })
    const body = await response.json()
    assert.strictEqual(body.task.description, 'foo')
  })

  it('handles a validation error on create', async function() {
    const response = await this.testClient.post('/api/tasks', {})
    assert(!response.ok)
    assert.strictEqual(response.status, 400)
    const body = await response.json()
    assert.strictEqual(
      body.error.message,
      'description: is a required property'
    )
  })

  it('handles an invalid task ID', async function() {
    const response = await this.testClient.delete(`/api/tasks/foo`)
    assert.strictEqual(response.status, 404)
  })
})
```

A few talking points:

- The tests generally follow a *state verification* pattern, in which we put the system into an initial state, provide some input to the system, and then verify the output or the final state, or both. For example, the setup for the `describe('with existing tasks', ...)` block creates two tasks in the database, and then the `it('completes a task', ...)` test makes a `DELETE` request and verifies that the service (1) produces the correct response code, [204](https://http.cat/204), and (2) puts the database into the expected state, in which there is only one uncompleted task left.

- The tests are [gray box](https://en.wikipedia.org/wiki/Gray_box_testing) tests, in that they are allowed to reach into the database (ideally through the model layer) to affect and inspect the state of the system. Here the API is complete enough that we could write these tests as [black box](https://en.wikipedia.org/wiki/Black-box_testing) tests using only the public API, but that is not always the case. Having access to the model layer in integration tests gives a lot of useful flexibility.

- The integration tests aim to cover all the success and error handling cases in the app's controllers, but they don't exhaustively test all of the possible causes of errors in the model layer, because those are covered in the model tests. For example, the `it('handles a validation error on create', ...)` test checks what happens if the description is missing, but there isn't an integration test for the case where a description that is too long, because there was a model test for that.

   This effect is a major contributor to the often talked about [test pyramid](https://martinfowler.com/articles/practical-test-pyramid.html), in which we have more model tests than integration tests. In this example, the model layer is too simple for that pattern to emerge, but the test pyramid is a good ideal to strive for in a large application. Integration tests generally take longer to run and require more effort to write than model tests, because there is much more going on --- making requests, receiving and deserializing responses, etc.. Other things being equal, it's usually best to test at the lowest level you can.

## Running the Tests

With model and integration tests in hand, let's see how to run them. We've seen above that the `bin/up` script creates separate `development` and `test` databases, so we have to set up the service to use them. This happens mainly in the [knexfile](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/knexfile.js):

```js
const common = {
  client: 'postgresql'
}

module.exports = {
  development: {
    ...common,
    connection: 'postgres://postgres:postgres@postgres/development'
  },
  test: {
    ...common,
    connection: 'postgres://postgres:postgres@postgres/test'
  },
  production: {
    ...common,
    connection: process.env.DATABASE_URL
  }
}
```

The development and test connection strings tell the application connect to postgres as the default `postgres` user, which has default password `postgres`, running on the host `postgres`, as declared in our Compose file. (It is a bit like that [buffalo buffalo sentence](https://en.wikipedia.org/wiki/Buffalo_buffalo_Buffalo_buffalo_buffalo_buffalo_Buffalo_buffalo).) In production, we assume that the service will be provided with a `DATABASE_URL` environment variable, because hard coding production credentials here would be a bad idea.

Then in the service's [`package.json`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/package.json) we can set up the test scripts to run with `NODE_ENV=test`, which is how the service knows to connect to the test database:
```json
"scripts": {
  "test": "NODE_ENV=test mocha 'test/**/*.test.js'",
  "test:model": "NODE_ENV=test mocha 'test/model/**/*.test.js'"
},
```

The `test:model` script runs only the model tests, which can be useful if you just want to run some model tests without the overhead of starting the express app in the global `before` hook, as mentioned above.

So, we are now ready to run `npm test` in a Docker container:
```shell
$ docker-compose run --rm todo npm test
Starting todo_postgres_1 ... done

> todo@1.0.0 test /srv/todo
> NODE_ENV=test mocha 'test/**/*.test.js'



  todo
    ✓ creates a task (123ms)
    ✓ handles a validation error on create
    ✓ handles an invalid task ID
    with existing tasks
      ✓ lists the tasks
      ✓ completes a task

  Task
    ✓ can be created with a valid description
    ✓ must have a description
    ✓ must not have an overly long description


  8 passing (349ms)
```
which is the name of the game for this blog post. (Or we can use the [`bin/test`](https://github.com/jdleesmiller/todo-demo/blob/todo-backend/todo/bin/test) helper script, which does the same thing.)

Finally, it's worth noting that to run a subset of the tests, mocha's grep flag works, provided that it is after a `--` delimiter to tell `npm` to pass it through to `mocha`. For example,
```
$ bin/test -- --grep Task
```
runs only the tests with names containing `Task`.

## Conclusion

We've seen how to write and run model and integration tests for a simple node.js web service with Docker and Docker Compose. Model tests exercise the core business logic in the model layer, and integration tests check that the core business logic is correctly wired up to the controller and view layers. Both types of tests benefit from being able to access the database, which is not mocked.

The Docker Compose setup for this project was pretty simple --- just one container for the application. We'll see some more advanced Docker Compose usage in subsequent posts, together with scripts like `bin/up` to help drive them.

Next time, we'll add a frontend so we can manage our TODO list without `curl`, and of course we will add some frontend tests. See you then!

<p>&nbsp;</p>
---
<p>&nbsp;</p>

If you've read this far, you should [follow me on twitter](https://twitter.com/jdleesmiller), or maybe even apply to work at [Overleaf](https://www.overleaf.com). `:)`

<p>&nbsp;</p>
---
<p>&nbsp;</p>

## Appendix: Views on Testing

This series of posts makes some assumptions about the kinds of automated tests that we're trying to write, so I should say what those assumptions are. I'll start with the big picture and work back to the practical.

So, why do we test? We test to *estimate correctness*. Good testing lets us iterate quickly to improve correctness by providing accurate and cheap estimates.

I say 'estimate' here because we can in principle measure 'ground truth' correctness by letting the system loose in the real world and seeing what happens. If we can release to production quickly and get feedback quickly through great monitoring, and if the cost of system failure is low, we might not need to estimate. For example, if we deliver pictures of cats at scale, we might just ship to production and measure; if we make antilock braking systems, not so much. In most domains, it is worth investing in testing so we can accurately predict and improve correctness before we go to production.

The main way to achieve high prediction accuracy is through high *fidelity*. As they say at NASA, [fly as you test, test as you fly](http://llis.nasa.gov/lesson/1196). For high fidelity, the system under test should closely resemble the one in production, and it should be tested in a way that closely resembles how it is used in production. However, fidelity usually comes at a cost.

There are two main costs to testing: the effort to create and maintain the tests, and the time to run the tests. Both are important. Software systems and their requirements change frequently, which requires developers to spend time adding and updating tests. And those tests run many, many times, which leaves developers twiddling their thumbs while they wait for test results.

Testing effectively requires finding the right tradeoff between fidelity and cost for your domain. This dynamic drives many decisions in testing. One example in this post is the decision to write both model tests and integration tests. We could just test everything with integration tests, which would be high fidelity but also high cost. Model tests are lower fidelity, in that they only test a part of the system, but they are generally easier to write and faster to run than integration tests, and hence lower cost.

The use of fakes (test doubles / mocks / stubs / etc.) is another important example; it can reduce test runtimes at the expense of lower fidelity and more effort to create and maintain the fakes. If replacing a component with a fake makes tests for other components much easier to write or faster to run without too much loss of fidelity, and it is not too much work to create and maintain the fake, it can be a good tradeoff.

Generally it makes sense to fake a component when two conditions hold: it is slow or unwieldy, and its coupling with the rest of the system is low. For example, if you want to test that your system sends an email when a user registers, you don't need to stand up a full SMTP server and email client in your test environment; it is better to just [fake the code](https://guides.rubyonrails.org/testing.html#testing-your-mailers) that sends the email. Third party APIs called over HTTP often fall into this category, too, especially because there are good tools, such as [vcr](https://github.com/vcr/vcr) and [polly.js](https://netflix.github.io/pollyjs), that make it easy to fake them.

One component I think it seldom makes sense to fake is the database. In most applications, coupling with the database is high, simply because some business logic is best handled by the database. The humble uniqueness constraint, for example, is very difficult to achieve without race conditions in application code but trivial with help of the database. And if you are fortunate enough to have a database that can do joins and enforce some basic data integrity constraints, you should definitely let it do that instead of endlessly rewriting that logic in application code. Given this coupling, including the database in the system under test increases fidelity and reduces costs to write and maintain tests, at the expense of longer test runtimes.

Fortunately, there are other ways to decrease test runtimes besides using fakes. A key property of testing is that it is [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel). Tests cases are independent by design, so it is straightforward (though not necessarily trivial) to run them in parallel. Some frameworks, [such as rails](https://guides.rubyonrails.org/testing.html#parallel-testing), can do this out of the box, and scalable Continuous Integration services make it easy to bring a lot of compute power to bear on your tests at relatively low cost. Of course, massive parallelism doesn't help so much if you are running the tests on your laptop, but in most cases you don't have to rerun the whole test suite to make progress on a single feature --- usually only a subset of the tests will be relevant. Then you can push the code to the beefy CI boxes to get a final check that the change hasn't broken something in an unexpected part of the application.

So, to sum up, in this series of blog posts I'm advocating for high fidelity (don't fake too much) and low costs to write and maintain tests (don't spend too much time tending fakes), with high investment in testing infrastructure to offset longer test runtimes. This does certainly make test environments more complex, but Docker and Docker Compose provide many useful tools for managing this complexity, which is one of the motivations for this series of blog posts.
