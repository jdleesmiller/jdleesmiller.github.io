---
layout: post
title: "Testing with Node and Docker Compose, Part 2: On the Frontend"
date: 2019-10-26 16:00:00 +0000
categories: articles
image: /assets/todo-demo/todo-demo-frontend.gif
description: Tutorial article about testing node.js applications under Docker and Docker Compose. Part 2 focuses on testing a React frontend.
---

This post is the second in a short series about automated testing in node.js web applications with Docker. Last time, we looked at [backend testing](/articles/2019/10/19/testing-node-docker-compose-backend.html); this time, we'll look at frontend testing.

To illustrate, we'll continue building and testing our example application: a simple TODO list manager. So far, we've built and tested a RESTful API to manage the task list:

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

In this post, we'll build and test a frontend that is hopefully more user friendly than `curl`! Here's what it will look like:

<p align="center">
  <a href="/assets/todo-demo/todo-demo-frontend.gif"><img src="/assets/todo-demo/todo-demo-frontend.gif" alt="Create some todos and complete them" style="max-width: 448px;"></a>
</p>

In particular, this post will cover:

- building a simple frontend with [React](https://reactjs.org/), [Bootstrap](https://getbootstrap.com/) and [Webpack](https://webpack.js.org/),
- building the frontend with a multi-stage Dockerfile, for both development and production,
- running backend and frontend containers in Docker Compose, and
- frontend testing with [jsdom](https://github.com/jsdom/jsdom), [React Testing Library](https://testing-library.com/docs/react-testing-library/intro), [fetch-mock](http://www.wheresrhys.co.uk/fetch-mock/) and [testdouble.js](https://github.com/testdouble/testdouble.js).

Subsequent posts will extend the approach developed here to include end-to-end testing and then multiple backend services.

The code is [available on GitHub](https://github.com/jdleesmiller/todo-demo), and each post in the series has a git tag that marks the [corresponding code](https://github.com/jdleesmiller/todo-demo/tree/todo-frontend/todo).

## The TODO List Manager Frontend

Let's start with a tour of the frontend we'll be developing and testing. The frontend comprises three React components, `App`, `NewTask` and `Task`, and a `taskStore` singleton. Here's an overview of how they interact:

<p align="center">
  <a href="/assets/todo-demo/todo-demo-frontend-architecture.svg"><img src="/assets/todo-demo/todo-demo-frontend-architecture.svg" alt="TODO"></a>
</p>

- The `taskStore` is a [singleton](https://en.wikipedia.org/wiki/Singleton_pattern) that holds the frontend's copy of the task list and makes requests to the backend API in response to user actions. (The term 'store' comes from redux, but this application doesn't actually use redux.)

- `App` is a coordinating component. It renders the top level UI, a `NewTask` component and one `Task` component for each task. It initiates the initial request for tasks when it's rendered, and it listens for the updated list of tasks from the `taskStore`. It puts the task list into its `state`, so when the task list changes, React will re-render the relevant parts of the UI.

- The `NewTask` component is responsible for creating new tasks, and the `Task` component is responsible for displaying a task allowing the user to mark it as completed. Both components call through to the `taskStore` when the user takes an action, which then updates the task list, which triggers a re-render as required.

Here's what some of the code looks like:

#### [`frontend/src/task-store.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/task-store.js)

```js
const TASKS_API_ROOT = '/api/tasks'

class TaskStore {
  constructor() {
    this.tasks = []
    this.listener = () => {}
  }

  listen(listener) {
    this.listener = listener
  }

  unlisten() {
    this.listener = () => {}
  }

  async list() {
    const response = await fetchJson(rootUrl())
    if (!response.ok) throw new Error('Failed to list tasks')
    const body = await response.json()
    this.tasks = body.tasks
    this.listener()
  }

  async create(description) {
    const response = await fetchJson(rootUrl(), {
      method: 'POST',
      body: JSON.stringify({ description })
    })
    if (!response.ok) {
      if (response.status === 400) {
        const body = await response.json()
        throw new Error(body.error.message)
      }
      throw new Error('Failed to create task')
    }
    await this.list()
  }

  async complete(id) {
    const response = await fetchJson(itemUrl(id), { method: 'DELETE' })
    if (!response.ok) throw new Error(`Failed to complete ${id}`)
    await response.text() // ignore
    await this.list()
  }
}

async function fetchJson(url, options) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json'
    },
    ...options
  })
  return response
}

function rootUrl() {
  return new URL(TASKS_API_ROOT, window.location.origin)
}

function itemUrl(id) {
  if (!id) throw new Error(`bad id: ${id}`)
  return new URL(id.toString(), rootUrl() + '/')
}

const taskStore = new TaskStore()

export default taskStore
```

A few notable points:

- The `taskStore` singleton implements a very simple event system: one listener can call `taskStore.listen` with a callback to be notified when the task list changes. In this case, there's only one listener, the `App` component, so this is sufficient, but of course a more general event system could be used if needed. Using events here helps reduce coupling between the store and the rest of the frontend; in particular, the logic in the store doesn't depend on React.

- The `taskStore` could try to be smart and update its `tasks` array in response to `create` and `complete` calls, but for now it just re-requests the whole task list from the backend whenever it knows the list has changed. This keeps the store simpler.

- It uses [`fetch`](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) to talk to the backend through a small wrapper function, `fetchJson`, which sets up the required headers. And it uses [`URL`](https://developer.mozilla.org/en-US/docs/Web/API/URL) to build the API URLs, to slightly reduce the amount of manual URL string munging required.

Next let's look at the `App` component, which uses the task list from the store:

#### [`frontend/src/component/app.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/component/app.js)

```jsx
import React from 'react'

import NewTask from './new-task'
import Task from './task'

import taskStore from '../task-store'

export default class App extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      tasks: null,
      listError: null
    }
  }

  componentDidMount() {
    taskStore.listen(() => this.setState({ tasks: taskStore.tasks }))
    this._listTasks()
  }

  componentWillUnmount() {
    taskStore.unlisten()
  }

  async _listTasks() {
    try {
      await taskStore.list()
    } catch (listError) {
      this.setState({ listError })
    }
  }

  render() {
    let listItems
    if (this.state.listError) {
      listItems = (
        <li className="list-group-item">
          Failed to load tasks. Please refresh the page.
        </li>
      )
    } else {
      if (this.state.tasks) {
        listItems = this.state.tasks.map(({ id, description }) => (
          <Task id={id} description={description} key={id} />
        ))
      } else {
        listItems = <li className="list-group-item">Loading&hellip;</li>
      }
    }

    return (
      <div className="container">
        <div className="row">
          <div className="col">
            <h1 className="mt-5 mb-3 text-center">TO DO</h1>
          </div>
        </div>
        <div className="row">
          <div className="col">
            <ul className="list-group">
              <NewTask />
              {listItems}
            </ul>
          </div>
        </div>
      </div>
    )
  }
}
```

It looks fairly long, but most of it is just error handling, latency compensation and some rather verbose HTML for bootstrap styles.

- The component starts off in a 'Loading&hellip;' state with no tasks.

- It asks the `taskStore` to start the first data fetch in the background and notify it of the results, using React's `componentDidMount` and `componentWillUnmount` lifecycle methods.

- Once the data comes back, it will render the list, or, if an error occurred display a (not particularly great) error message.

The child components handle most of the UI. Let's look at the `Task` component:

#### [`frontend/src/component/task.js`](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/component/task.js)
{% raw %}
```jsx
import PropTypes from 'prop-types'
import React, { useState, useEffect } from 'react'

import taskStore from '../task-store'

const Task = ({ id, description }) => {
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    let unmounted = false

    async function update() {
      try {
        await taskStore.complete(id)
      } catch (err) {
        alert(err.message)
      } finally {
        if (!unmounted) setSubmitting(false)
      }
    }
    if (submitting) update()

    return () => {
      unmounted = true
    }
  }, [submitting])

  return (
    <li className="list-group-item todo-task">
      <form
        onSubmit={e => {
          setSubmitting(true)
          e.preventDefault()
        }}
      >
        <p>
          <span>{description}</span>
          <button
            className="btn btn-success float-right"
            type="submit"
            style={{ minWidth: '3em' }}
            disabled={submitting}
            aria-label={`mark ${description} complete`}
          >
            ✓
          </button>
        </p>
      </form>
    </li>
  )
}

Task.propTypes = {
  id: PropTypes.number,
  description: PropTypes.string
}

export default Task
```
{% endraw %}

This is a smaller component, but again there are still a few things to comment on:

- Since the component is mostly driven by its `props` and has relatively little state, I've written it as a functional component that uses [React hooks](https://reactjs.org/docs/hooks-intro.html). It has one state variable, `submitting`, that tracks whether there is currently a submission in progress and disables the button.

- Because the `taskStore` updates the list asynchronously, the `taskStore.complete` call can finish after the component has been unmounted, in which case trying to update the state is an error. The `unmounted` variable tracks when the component is unmounted, to avoid this.

- The button sets an `aria-label` to be friendlier to screen readers. We'll also see that it's helpful in testing, later.

The [`NewTask` component](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/component/new-task.js) is similar, so I won't bore you further with the details.

Finally, to bring it together, we also need [an `index.html` file](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/index.html) and [an entrypoint](https://github.com/jdleesmiller/todo-demo/blob/todo-frontend/todo/frontend/src/index.js) to load up all our various polyfills and render the `App` component.

## Packaging

Now that we have the code, let's see how to build it.

---

# Scratch

- The `useEffect` is a bit cryptic. As it is used here, it essentially combines the `componentDidMount` and `componentWillUnmount` [component lifecycle methods](https://reactjs.org/docs/state-and-lifecycle.html). The empty array passed to `useEffect` causes the callback to run only once, when the component has mounted, at which point the component registers itself as a listener on the store and initiates the first data fetch. This callback then returns a second callback that React will call when the component is unmounted, which unregisters the component as a listener. (On the one hand, it's nice that the hook approach keeps this setup and teardown logic together; on the other hand, the classic lifecycle methods are a lot more self-explanatory.)

- Aside from rendering the list, the component can also render either an error message, if the list request has failed, or a loading message, if we are still waiting for the first fetch.
