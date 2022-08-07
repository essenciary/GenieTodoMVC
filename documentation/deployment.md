# Deploying Genie applications in production

Genie, together with some of the packages available in the ecosystem provide a a multitude of useful features for deploying
and running applications in production.

## Genie app environments

Genie applications run in the context of an environment, which represents a way of configuring the application with a set of settings.
In other words, we can define multiple environments, each with its specific configuration, and then we can easily swap the environment
in order to apply all the settings at once.

By default Genie apps are created with 3 environments: dev (which stands for development), prod (for production), and test (for testing).
Each environment has its own configuration file with the same name, placed inside the config/env/ folder of the app. These
environments come with preconfigured settings for three common situations.

The first one is `dev`, which is the default environment that the app uses, is optimised for running the application during development. It provides
certain features that make the development process more efficient and productive, such as code reloading and recompilation
every time when files are saved (by automatically setting up file loading with the Revise.jl package), extensive and rich error messages, and
automatic serving of assets like images, stylesheets and scripts.
The `dev` environment also has sensible settings for running the application locally, such as using the `127.0.0.1` host and the
default Genie port, 8000.

However, the development features such as code reloading, rich error messages, or asset serving are not appropriate when we run
the application in production either because they slow down the application or because they can expose sensitive information
that can be exploited by attackers. And here comes in handy the `prod` environment which provides configurations that are optimised
for running the application in production. As you might have guessed, the `prod` environment disables code reloading and recompilation,
disables detailed error messages, and recommends the disabling of assets serving. In addition, productions apps will use by
default the host `0.0.0.0`, which is usually what's expected when deploying on most hosting platforms.

Finally, the third bundled environment, `test`, is optimized for testing the application, and we've already seen it in action
in the section about unit tests.

### Customizing the environments

We can edit the environment files in order to change, remove, or add configuration elements. Take for instance the default `dev.jl` file:

```julia
using Genie, Logging

Genie.Configuration.config!(
  server_port                     = 8000,
  server_host                     = "127.0.0.1",
  log_level                       = Logging.Info,
  log_to_file                     = false,
  server_handle_static_files      = true,
  path_build                      = "build",
  format_julia_builds             = true,
  format_html_output              = true,
  watch                           = true
)

ENV["JULIA_REVISE"] = "auto"
```

The `config!` method modifies and returns the `Genie.config` object, which is an instance of `Genie.Configuration.Settings` and
represents the application's configuration. You can probably recognize here some of the configurations we have already mentioned,
like for instance the host and the port of the application, the logging settings, handling of assets (static files), or various
formatting options that are useful for development together with watching for file changes.

We can also add environment dependent settings, like for instance the `JULIA_REVISE` configuration which sets automatic file
re-compilation when files changes by employing the Revise.jl package.

By contrast, take a look at the default `prod.jl` file:

```julia
using Genie, Logging

Genie.Configuration.config!(
  server_port                     = 8000,
  server_host                     = "0.0.0.0",
  log_level                       = Logging.Error,
  log_to_file                     = false,
  server_handle_static_files      = true, # for best performance set up Nginx or Apache web proxies and set this to false
  path_build                      = "build",
  format_julia_builds             = false,
  format_html_output              = false
)

if Genie.config.server_handle_static_files
  @warn("For performance reasons Genie should not serve static files (.css, .js, .jpg, .png, etc) in production.
         It is recommended to set up Apache or Nginx as a reverse proxy and cache to serve static assets.")
end

ENV["JULIA_REVISE"] = "off"
```

We can see the differences in server configuration (host and port), logging, formatters, and automatic recompilation.

### Creating extra environments

The three default environments cover some of the most common use cases, but we can define other environments as needed. For
instance, many development teams commonly use a staging environment, as an intermediary stage between development and production.
All we need to do in order to enable a new environment is to create the corresponding env file. For instance, we can create a
copy of our `prod.jl` file and name it `staging.jl` to define a staging environment -- and modifying as necessary:

```julia
# config/env/staging.jl
using Genie, Logging

Genie.Configuration.config!(
  server_port                     = 8000,
  server_host                     = "0.0.0.0",
  log_level                       = Logging.Debug,
  log_to_file                     = true,
  server_handle_static_files      = true, # for best performance set up Nginx or Apache web proxies and set this to false
  path_build                      = "build",
  format_julia_builds             = true,
  format_html_output              = true
)

ENV["JULIA_REVISE"] = "off"
```

The snippet shows a possible `staging` configuration where we keep some of the production settings but enable more comprehensive
logging and some extra formatting to help us debug potential issues.

### SearchLight database environments

Equally important is the ability to automatically configure the database connection based on environments. SearchLight integrates
with Genie's envs, to dynamically pick the right database connection. This is very important in order to avoid that we
accidentally pollute or destroy production data when we run our application in development or test.

Remember that we have already configured a distinct test database in our db/connection.yml file.

```yaml
env: ENV["GENIE_ENV"]

dev:
  adapter:  SQLite
  database: db/dev.sqlite3

test:
  adapter:  SQLite
  database: db/test.sqlite3
```

See how at the top of the file we set `env` to automatically pick the application's environment, which in turn allows SearchLight
to connect to the corresponding database.

### Changing the active environment

In the section about unit tests, we have seen how the very first thing in the `test/runtests.jl` file, our test runner,
is to change the environment of the application to `test`. Now we understand why this is important in order to apply the right
configuration during tests and to connect to the right SearchLight database.

As such, one way of changing the applications' environment is by passing the env's name as a Julia environment variable, either by
setting it in the `ENV` global, or by passing it as a command line argument when starting the app. We'll see in just a minute
how to switch our application to run in production -- but before we can do that, there's one thing we need to do: prepare the database.

We have not defined a database configuration for our prod environment, and this will cause the app to error out at startup.
So let's make sure we add it first. Append the following to the end of the `db/connection.yml` file:

```yaml
prod:
  adapter:  SQLite
  database: db/prod.sqlite3
```

SearchLight will create the `prod.sqlite3` database next time we start the app in the `prod` environment. Let's see how it's done.

#### Starting the application in production

By default Genie apps start in development, as that is the logical first step once an app is created: to develop it. But we
can easily change the active environment at any time - however, this must be done when the app is started, in order to allow
the proper loading of the environment's settings. As such, changing the environment requires restarting the app.

##### Using environment variables

One way to change the active environment is by passing the app's active env as a command line environment variable.
Environment variables are key-value pairs, stored by Julia in the `ENV` collection, which offer information
about the current context of the Julia execution. We can access these variables from within our app as `ENV["<variable_name>"]`.
We can define our environment variables when starting our app, by passing them as extra command line arguments. For instance,
we can configure our Genie app to not show the Genie loading banner and overwrite the web server port by running our app as:

```bash
GENIE_BANNER=false PORT=9999 bin/server
```

This will disable the Genie banner and will start the application on port 9999, producing the following output:

```bash
> GENIE_BANNER=false PORT=9999 bin/server

Ready!

┌ Info: 2022-08-07 16:21:56
└ Web Server starting at http://127.0.0.1:9999 - press Ctrl/Cmd+C to stop the server.
```

We can pass the `GENIE_ENV` environment variable to our script in order to start the app with the designated environment, for
example:

```bash
> GENIE_ENV=prod bin/server
```

or maybe

```bash
> GENIE_ENV=test bin/repl
```

##### Using `config/env/global.jl`

You may have noticed that in the `config/env` folder there is a `global.jl` file that by default only contains a comment.
As the comment indicates, we can use this file to define and apply _global_ configuration variables - that is, settings that
will be applied to all the environments. Think of it as a way to avoid copying the same settings in all the environment files.

However, as this file is loaded right before the specific environment file for the app, we can actually use it to change the
active environment. For instance, if we add this line to the `global.jl` file, our application will always run in `prod` env:

```julia
ENV["GENIE_ENV"] = "prod"
```

**Beware that setting the active env in the `global.jl` file will overwrite the configuration set via `GENIE_ENV`.**

#### Running the app in production

Let's restart our app now in production, for example by using the `GENIE_ENV` environment variable:

```bash
> GENIE_ENV=prod bin/repl
```

Upon restarting the app in prod our database was automatically created, but SearchLight has only created an empty db.
We need to set up the database structure by running the database migrations.

```julia
julia> using SearchLight

julia> SearchLight.Migration.init()

julia> SearchLight.Migration.all_up!!()
```

Now everything is ready for our app to run in production. We can test it by starting the server (`julia> up()`) and visiting
<http://localhost:8000>. Our todo app should run as expected - but of course, you won't be able to see any of the todo items
you may have added in development, as in production the app is using the new production db. You'll find the todo items when
restarting the app in `dev` mode again. This level of data isolation provided by application environments ensures that we
don't accidentally run dev or test code in production.

With our app fully configured for running in production, we're now ready to deploy on the internet.

## Containerizing Genie apps with Docker and GenieDeployDocker

Docker deployments are the most common way of releasing and scaling web applications as part of devops workflows. Genie has
official support for Docker containerization via the GenieDeployDocker plugin. Let's use it to containerize our app.

We'll start by adding the `GenieDeployDocker` package: `pkg> add GenieDeployDocker`

Once installed we'll use it to generate a `Dockerfile` for our application (the `Dockerfile` is the configuration file that
tells Docker how to containerize our app):

```julia
julia> using GenieDeployDocker

julia> GenieDeployDocker.dockerfile()
Docker file successfully written at .../TodoMVC/Dockerfile
```

If you're familiar with Docker you can take a look at the resulting `Dockerfile`. Right out of the box it contains everything
that is needed in order to set up a Linux container with Julia, and set up our application, with its dependencies, and start
the server to listen on the designated ports. You can read more about `Dockerfile` in the official Docker documentation at
<https://docs.docker.com/engine/reference/builder/>.

We'll need to make only one change in the `Dockerfile` - towards the bottom there is a line that reads `ENV GENIE_ENV "dev"`.
This sets the environment used by the app. By default it's set to `dev` - edit this line and set the app's environment to
`prod`.

Now that we have a `Dockerfile` we can ask Docker to build our container.

```julia
julia> GenieDeployDocker.build()
```

This process can take a bit as Docker will pull the linux OS image from the internet, install and precompile our app's
dependencies, copy our application into the linux container, and finally run the app by starting the server. As you run the
`build` command you'll be able to follow the progress of the various steps as the REPL's output.

Once the build finishes, we can "deploy" our application in the Docker container locally - that is, run the container and
access the application on our computer. Let's do it to confirm that everything works as expected:

```julia
julia> GenieDeployDocker.run()
```

This will start our Genie application inside the Docker container, in the production environment, by running the `bin/server` script.
In addition, per the instructions in the `Dockerfile`, it will bind the app's port inside the container (set to 8000) to
the port 80 of the Docker host (that is, your computer). This means that, after the familiar Genie loading screen, once confirmed
that the application is ready, you can access it by simply visiting <http://localhost> in your browser.

## Setting up our Github repo

In this step we'll set up a Github repo for our TodoMVC app. We'll use Github to for two main actions: to set up CI (Continuous
Integration) and have Github Actions run our test suite every time we push to the repo; and to serve as a public repo that
we can access from our deployment servers.

For the following actions you will need a free Github account. Login to your Github account and create a new repo to host the app at
<https://github.com/new>. Give it a good name, like `GenieTodoMVC`. Put a description too if you want then click on "Create repository".

Once the Github repo is created we need to configure your local Genie app to use it. Going back to your computer, in the terminal, in
the app's folder, run the following (you will need to have `git` installed on your computer):

```bash
> git init
> git commit -m "initial commit"
> git branch -M main
> git remote add origin <HTTPS URL OF YOUR GITHUB REPO>
> git push -u origin main
```

### Setting up Github CI



## Deploying Genie apps with Git and Docker containers

Now that we have confirmed that our application runs correctly in a Docker container, we can deploy our application on any of
the multitude of web hosting services that support Docker container deployments. By using Docker containers, we can be sure
that the exact setup described in the `Dockerfile` and tested on our machine will be run and configured by our hosting service.

### AWS



## Deploying Genie apps behind a web server

### Nginx

### Apache

### Caddy