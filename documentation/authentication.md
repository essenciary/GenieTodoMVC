# Authentication

We've made great progress so far, developing our todo app and hosting it on the web. However, making our application available
on the internet introduces a new problem: how do we keep our data safe? Anybody who knows the URL of our app can access it
and can see all of our todos. We need to add some kind of authentication to our app so that only authorized users can access
it. In addition, wouldn't it be nice if we could share our todo app with our friends and family so they could also create their
list and keep track of their todos?

The solution for these is to add an authentication layer to our app. The authentication will ensure that only authorized users
can see specific todo items. In other words, before allowing users to create or edit todo items, we will ask the users to
authenticate themselves. If they are new to the website they will be asked to register. If they are already registered, they
will be able to use their credentials (username and password) to log in. In addition, we will also make sure that each todo
item is associated with a specific user. This way, only the user who created the todo item will be able to see it.

## Adding Authentication to our App

The easiest way to add authentication to a Genie app is to use the GenieAuthentication plugin. Let's add it and follow the
installation instructions (<https://github.com/GenieFramework/GenieAuthentication.jl>) to set up our app for authentication.

In a terminal start the Genie REPL for the TodoMVC app: go to the application folder and run `bin/repl` if you are on Linux or Mac,
or `bin\repl.bat` if you are on Windows. Then, in the REPL, type `]` to enter the Pkg mode and add the GenieAuthentication plugin:

```julia
pkg> add GenieAuthentication
```

Once the plugin is installed, we need to configure it:

```julia
julia> using GenieAuthentication
julia> GenieAuthentication.install(@__DIR__)
```

By running the `install` function, the plugin has added all the necessary integrations into our app (views, controller, model,
migrations, etc). You can see all the operations performed by the `install` function by looking at output in the REPL.

### Configuring the GenieAuthentication plugin

Now that the plugin is installed, let's configure it to our needs. First, we said that we want to allow users to register, so
let's enable this functionality. Registration is disabled by default as a security precautions, to make sure that we don't
accidentally allow unwanted registrations on our app. To enable user registration we need to edit the newly created `genie_authentication.jl`
file in the `plugins/` folder (this was one of the files created by the `install` function). Open the file and uncomment the
two routes at the bottom of the file:

```julia
# UNCOMMENT TO ENABLE REGISTRATION ROUTES

route("/register", AuthenticationController.show_register, named = :show_register)
route("/register", AuthenticationController.register, method = POST, named = :register)
```

#### What are the plugins?

In case you are wondering about this `plugins/` folder, it's worth mentioning that this is a "special" Genie folder. The files
placed inside this folder behave very similarly to the initializer files hosted in the `config/initializers/` folder. The
`plugins/` folder is designed to be used by Genie plugins to add their integration and initialization logic - and the only difference
compared to regular initializers is that the files in the `plugins/` folder are loaded after the initializers so they can
get access to all the features of the Genie app (like say the database connection, logging, etc).

### Setting up the database

The GenieAuthentication plugin stores the user information in the application's database. For this reason we'll need to create
a new table to store the user information. The plugin has created a migration file for us in the `migrations/` folder. Let's
run the migration to create the `users` table. Go back to the Genie app REPL and run:

```julia
julia> using SearchLight
julia> SearchLight.Migration.status()
```

This will show us the status of the migrations. We can see that we have one migration, `create_table_users`, that has not
been run yet. Let's run it:

```julia
julia> SearchLight.Migration.allup()
```

The `Migration.allup` function will run the migrations that have not been run yet. Alternatively, we can run a specific migration by
passing its name to the `Migration.up` function, for example in our case: `SearchLight.Migration.up("CreateTableUsers")`.

Running the migration will create a new table in the database called `users`. The table only includes a minimum set of columns
that are required by the GenieAuthentication plugin: `id`, `username`, `password`, `name` and `email`. If you want to customize
this structure you can edit the migration before running it or create additional migrations.

### Restricting access to the app

It's time to give our authentication feature a try. Let's go ahead and restrict access to the list of todo items. To do this
edit the `app/resources/todos/TodosController.jl` file as follows:

1) at the top of the file, under the last `using` statement, add the following:

```julia
using GenieAuthentication
using TodoMVC.AuthenticationController
```

2) change the `index` function by adding the `authenticated!()` function call -- this effectively restricts access to the
body of the function to only authenticated users. The updated `index` function should look like this:

```julia
function index()
  authenticated!()

  html(:todos, :index; todos = todos(), count_todos()..., ViewHelper.active)
end
```

That's all we need to do for now in terms of code. However, before testing our app we need to reload it to give Genie the
opportunity to load the plugin. Exit the Genie REPL and start it again -- then start the server `julia> up()` and open the
application in the browser (<http://localhost:8000>).

### Registering a new user

This time, however, we will not be able to see the list of todos. Instead, we will be redirected to the login page because we
are not authenticated. Let's enable the registration functionality and create a new user. We have already enabled the registration
routes earlier by uncommenting the routes. We'll need to do the same for the registration link in the login page. Open the
`app/resources/authentication/views/login.jl` file and uncomment the section at the bottom of the file by deleting the first and
last lines (the ones that say "Uncomment to enable registration"):

```html
<!-- Uncomment to enable registration
<div class="bs-callout bs-callout-primary">
  <p>
    Not registered yet? <a href="$(linkto(:register))">Register</a>
  </p>
</div>
Uncomment to enable registration -->
```

After you delete the two lines and reload the page, at the bottom, under the login form, you should see a link to the registration.
Clicking on the "Register" link will take us to the registration page, displaying a form that allows us to create a new account.
Let's fill it up with some data and create a new user. Upon successful registration by default we will get a message saying
"Registration successful". Let's improve on this by redirecting the user to their todo list instead. Edit the
`app/resources/authentication/AuthenticationController.jl` file and change the `register` function. Look for the line that says
"Redirect successful" and replace it with `redirect("/?success=Registration successful")`.

Let's try out the new flow by navigating back to the registration page <http://localhost:8000/register> and creating a new user.
This time, after the successful registration the user will be automatically logged in and will be taken to the todo list page,
with the app displaying a success message, notifying that the registration was successful.

If you want, you can also try an invalid registration, for example by reusing the same username or by leaving some of the fields
empty. You will see that the plugin will automatically guard against such issues, blocking the invalid registration and displaying
a default error message, indicating the problematic field. As a useful exercise, you can further improve the registration
experience by customizing the error message.

Note: as we haven't added a "logoff" button yet, you can logoff by navigating to <http://localhost:8000/logout>.

### Restricting access to the data

Our app is now protected by authentication, but we still need to make sure that the user can only see their own todo items. To
do this we need to modify our app so that for each todo item we also store the user id that created the todo, effectively
associating each todo item with a user. Once we have that we'll need to further modify our code to only retrieve the todo items
that belong to the currently logged in user.

#### Adding the user id to the todo items

In order to associate each todo item with a user we need to add a new column to the `todos` table. This means we'll need to create
a new migration. Let's do that by running the following command in the Genie REPL:

```julia
julia> using SearchLight
julia> SearchLight.Migration.new("add column user_id to todos")
```

This will create a new migration `AddColumnUserIdToTodos` -- let's edit it to put in our logic. In the `db/migrations/` folder
open the file that ends in `add_column_user_id_to_todos.jl` and make it look like this:

```julia
module AddColumnUserIdToTodos

import SearchLight.Migrations: add_columns, remove_columns, add_index, remove_index

function up()
  add_columns(:todos, [
    :user_id => :int
  ])

  add_index(:todos, :user_id)
end

function down()
  remove_index(:todos, :user_id)

  remove_columns(:todos, [
    :user_id
  ])
end

end
```

The migration syntax should be familiar to you by now. We are adding a new column called `user_id` to the `todos` table and
a new index on that column (this is a good practice to improve the performance of queries given that we will filter the todos
by the data in this column). The `down` function will undo the changes made by the `up` function, by first removing the index and
then dropping the column. Let's run our migration:

```julia
julia> SearchLight.Migration.up()
```

##### Modifying the Todo model

Now that we have the new column in the database we need to modify the `Todo` model to include it. Open the `app/resources/todos/Todos.jl` file
and change the model definition to look like this:

```julia
@kwdef mutable struct Todo <: AbstractModel
  id::DbId = DbId()
  todo::String = ""
  completed::Bool = false
  user_id::DbId = DbId()
end
```

We have added a new field called `user_id` of type `DbId` which will be used to reference the id of the user that created the todo.

**Important**: Julia requires a restart when definitions of `struct`s are changed. Exit the Genie REPL and start it again, otherwise
the application will not work correctly from this point on.

Now that we have added the column to store the user id of the owner of the todo item let's update our existing todo items to
set their `user_id` to the id of our user. This is the id of the user that we just created during the registration process. If
you want to check what users are in the database run the following at the Genie app REPL:

```julia
julia> using TodoMVC.Users
julia> all(User)
```

You will get a list of all users in the database. In my case, it looks like this:

```julia
2-element Vector{User}:
 User
| KEY              | VALUE                                                            |
|------------------|------------------------------------------------------------------|
| email::String    | adrian@geniecloud.io                                             |
| id::DbId         | 1                                                                |
| name::String     | Adrian                                                           |
| password::String | d74ff0ee8da3b9806b18c877dbf29bbde50b5bd8e4dad7a3a725000feb82e8f1 |
| username::String | adrian                                                           |

 User
| KEY              | VALUE                                                            |
|------------------|------------------------------------------------------------------|
| email::String    | j@j.com                                                          |
| id::DbId         | 2                                                                |
| name::String     | John                                                             |
| password::String | 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4 |
| username::String | john                                                             |
```

Note: if you haven't created a user for yourself yet, do that now by navigating to <http://localhost:8000/register> and registering.

Let's check the `id` of our user -- that is, the user that will be associated with the todo items we previously created. In my case,
the id is 1. Now let's update the existing todo items to set their `user_id` to 1 (or whatever id has the user you want to use).
Run the following at the Genie app REPL:

```julia
julia> for t in all(Todo)
          t.user_id = 1
          save!(t)
       end
```

Now all our existing todos are associated with the id of the user. Two more things left: first, filter the todos by the user id
of the authenticated user when retrieving them, and second, make sure that the user id is set when creating a new todo item.

##### Filtering the todos by user id

Let's proceed by updating our application logic to filter the todos by the user id of the authenticated user. Open the `app/resources/todos/TodosController.jl` file
and make the following changes:

+ in the `count_todos` function, we add a new filter -- `user_id = current_user_id()` -- to the `count` function to only
count the todos that belong to the authenticated user:

```julia
function count_todos()
  notdonetodos = count(Todo, completed = false, user_id = current_user_id())
  donetodos = count(Todo, completed = true, user_id = current_user_id())

  (
    notdonetodos = notdonetodos,
    donetodos = donetodos,
    alltodos = notdonetodos + donetodos
  )
end
```

+ in the `todos` function, we add the same filter to all the `find` calls:

```julia
function todos()
  todos = if params(:filter, "") == "done"
    find(Todo, completed = true, user_id = current_user_id())
  elseif params(:filter, "") == "notdone"
    find(Todo, completed = false, user_id = current_user_id())
  else
    find(Todo;  limit = params(:limit, SearchLight.SQLLimit_ALL) |> SQLLimit,
                offset = (parse(Int, params(:page, "1"))-1) * parse(Int, params(:limit, "0")),
                user_id = current_user_id())
  end
end
```

+ then we apply the same logic to the `toggle`, `update` and `delete` functions:

```julia
function toggle()
  todo = findone(Todo, id = params(:id), user_id = current_user_id())
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  todo.completed = ! todo.completed

  save(todo) && json(todo)
end

function update()
  todo = findone(Todo, id = params(:id), user_id = current_user_id())
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  todo.todo = replace(jsonpayload("todo"), "<br>"=>"")

  save(todo) && json(todo)
end

function delete()
  todo = findone(Todo, id = params(:id), user_id = current_user_id())
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  SearchLight.delete(todo)

  json(Dict(:id => (:value => params(:id))))
end
```