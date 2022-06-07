# Genie Todo MVC walk through

## Creating a new app

Genie includes various handy generators for bootstrapping new applications. These generators setup the necessary packages and application files in order to streamline the creation of various types of projects, including full stack (MVC) apps and APIs.

As we're creating a MVC app, we'll use the MVC generator.

```julia
julia> using Genie
julia> Genie.Generator.newapp_mvc("TodoMVC")
```

We invoke the `newapp_mvc` generator, passing the name of our new applications. Genie integrates with various database backends through SearchLight, an ORM library that provides a reach API to work with relational DBs. As MVC apps routinely use database backends, the generator gives us the possibility to configure the DB connection now. SearchLight makes it very easy to write code that is portable between the supported backends, so our plan is to use SQLite during development (for ease of configuring) and Postgres or MariaDB in production (for high performance under live online traffic).

```
Please choose the DB backend you want to use:
1. SQLite
2. MySQL
3. PostgreSQL
4. Skip installing DB support at this time

Input 1, 2, 3 or 4 and press ENTER to confirm.
If you are not sure what to pick, choose 1 (SQLite). It is the simplest option to get you started right away.
You can add support for additional databases anytime later.
```

Inputting `1` will install and configure SQLite and the SearchLight SQLite adapter. When ready, Genie will load our newly created app and will start the web server on port 8000:

```

 ██████╗ ███████╗███╗   ██╗██╗███████╗    ███████╗
██╔════╝ ██╔════╝████╗  ██║██║██╔════╝    ██╔════╝
██║  ███╗█████╗  ██╔██╗ ██║██║█████╗      ███████╗
██║   ██║██╔══╝  ██║╚██╗██║██║██╔══╝      ╚════██║
╚██████╔╝███████╗██║ ╚████║██║███████╗    ███████║
 ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚══════╝    ╚══════╝

| Website  https://genieframework.com
| GitHub   https://github.com/genieframework
| Docs     https://genieframework.com/docs
| Discord  https://discord.com/invite/9zyZbD6J7H
| Twitter  https://twitter.com/essenciary

Active env: DEV


Ready!

┌ Info:
└ Web Server starting at http://127.0.0.1:8000
```

We can check that everything works by navigating to the indicated url (`http://127.0.0.1:8000`) in the browser. We should see Genie's welcome page.

```

Welcome!
It works! You have successfully created and started your Genie app.
```

## Setting up the database

Because various relational database backends support different features and flavours as SQL, when working with SearchLight we use a set of programming APIs and workflows that ensure that our code that interacts with the database can be ported across the different supported backends. This pattern also covers table creation and modification, which is done via "migration" scripts. Besides being database agnostic, migration scripts provide another very important advantage: they allow versioning and automating/repeating table creation and modification operations, for example between multiple team members or when deploying the app in production.

Before we can use migrations to create our table we need to setup the migrations infrastructure: a table stored in the app's db, where `SearchLight.Migrations` keeps track of the various migration scripts. This is easily done with another generator:

```julia
julia> using SearchLight
julia> SearchLight.Migrations.init()
```

We get the following output:

```
┌ Info: CREATE TABLE `schema_migrations` (
│       `version` varchar(30) NOT NULL DEFAULT '',
│       PRIMARY KEY (`version`)
└     )
[ Info: Created table schema_migrations
```

## Creating our table

Our application will need a database table to store the todos. We'll also need a way to interact with this database table, in order to store, retrieve, update and potentially delete todo items. This is done using "Models", the "M" in the "MVC" stack. SearchLight has a series of generators that allow us to quickly create models and their respective migrations, plus a few other useful files.

```julia
julia> SearchLight.Generator.newresource("Todo")
```

We'll get the following output, informing us that four files have been created.

```
[ Info: New model created at TodoMVC/app/resources/todos/Todos.jl
[ Info: New table migration created at TodoMVC/db/migrations/<timestamp>_create_table_todos.jl
[ Info: New validator created at TodoMVC/app/resources/todos/TodosValidator.jl
[ Info: New unit test created at TodoMVC/test/todos_test.jl
```

A resource represents a business entity or a piece of data (in our case a todo item) implemented in code through a bundle of files serving various roles. For now we'll focus on the model and the migration - but notice that SearchLight has also created a validator and a test file. We'll get back to these later.

### The migration

As we can see in the output above, the migration file has been created inside the `db/migrations/` folder. The file name ends in `_create_table_todos.jl` and begins with a timestamp of the moment the file was created. The purpose for timestamping the migration file is to reduce the risk of name conflicts when working with a team -- but also to inform SearchLight about the creation and execution order of the migration files.

Let's check out the file. It looks like this:

```julia
module CreateTableTodos

import SearchLight.Migrations: create_table, column, columns, pk, add_index, drop_table, add_indices

function up()
  create_table(:todos) do
    [
      pk()
      column(:column_name, :column_type)
      columns([
        :column_name => :column_type
      ])
    ]
  end

  add_index(:todos, :column_name)
  add_indices(:todos, :column_name_1, :column_name_2)
end

function down()
  drop_table(:todos)
end

end
```

SearchLight has added some boilerplate code to get us started - we just need to fill up the placeholders with the names and properties of our table's columns. The Migrations API should be pretty self explanatory, but let's go over it quickly. We have two functions `up` and `down`. In migrations parlance, the `up` function is used to apply the database modification logic. So any changes we want to make, should go into the `up` function. Conversely, the `down` function contains logic for undoing the changes introduced by `up`.

Moving on to the contents of the `up` function, in creates a table called `todos` (`create_table(:todos)`), adds a primary key (`pk()`) and then provides boilerplate for adding a number of columns and indices. The `down` function deletes the table (`drop_table(:todos)`) undoing the effects of `up`.

In the spirit of traditional TodoMVC apps we'll keep it simple and we'll only store the todo item itself (we'll call it `todo`) and we'll store whether or not it's completed (by default not). Let's set up the `up` logic:

```julia
module CreateTableTodos

import SearchLight.Migrations: create_table, column, columns, pk, add_index, drop_table, add_indices

function up()
  create_table(:todos) do
    [
      pk()
      column(:todo, :string)
      column(:completed, :bool; default = false)
    ]
  end

  add_index(:todos, :completed)
end

function down()
  drop_table(:todos)
end

end
```

We're now ready to execute our migration (execute the code within the `up` function). The `SearchLight.Migration` API provides a series of utilities to work with migrations, for instance to keep track of which migrations have been executed, and execute migrations in the correct order. We can check the status of our migrations:

```julia
julia> SearchLight.Migrations.status()
```

Output:

```
[ Info: SELECT version FROM schema_migrations ORDER BY version DESC
|   | Module name & status                   |
|   | File name                              |
|---|----------------------------------------|
|   |                 CreateTableTodos: DOWN |
| 1 |      <timestamp>_create_table_todos.jl |
```

As expected, our migration is down, meaning that we haven't run the `up` function to apply the changes to the database. Let's do it:

```julia
julia> SearchLight.Migrations.up()
```

We can see all the steps executed by the `up` function:

```
[ Info: SELECT version FROM schema_migrations ORDER BY version DESC
[ Info: CREATE TABLE todos (id INTEGER PRIMARY KEY , todo TEXT  , completed BOOLEAN  DEFAULT false  )
[ Info: CREATE  INDEX todos__idx_completed ON todos (completed)
[ Info: INSERT INTO schema_migrations VALUES ('2022052910095674')
[ Info: Executed migration CreateTableTodos up
```

If we check again we'll see that the migration's status is now `UP`:

```julia
julia> SearchLight.Migrations.status()
```

Output:

```
[ Info: SELECT version FROM schema_migrations ORDER BY version DESC
|   | Module name & status                   |
|   | File name                              |
|---|----------------------------------------|
|   |                   CreateTableTodos: UP |
| 1 | 2022052910095674_create_table_todos.jl |
```

## Setting up the model

Interacting with the Migrations API we have seen the effectiveness of an ORM: writing concise and readable Julia code, SearchLight generates a multitude of SQL queries that are optimised for the configured database backend (in our case SQLite). This idea is taken to its next step by models: the models are even more powerful constructs that allow us to manipulate the _data_ (compared to migrations, which manipulate the tables's _structure_). A model is a Julia struct whose fields (properties) map the table columns that we want to control. By setting up these structs we retrieve data from our database tables -- and by changing the values of their fields, we write data back to the database.

Remember that our model was created in the `app/resources/todos/` folder, under the name `Todos.jl`. Let's open it in our editor.

```julia
module Todos

import SearchLight: AbstractModel, DbId
import Base: @kwdef

export Todo

@kwdef mutable struct Todo <: AbstractModel
  id::DbId = DbId()
end

end
```

Similar to the migration, SearchLight has set up a good amount of boilerplate to get us started. The model struct is included into a module. Notice that the name of the modules is pluralized, like the name of the table -- while the struct is singular. The table contains multiple _todos_; and each `Todo` struct represents one row in the table, that is, one todo item.

The struct already includes the `id` field corresponding to the primary key. Let's add the other two fields, corresponding to the todo and the completed status. These fields must match the names of the types we declared in the migration.

```julia
module Todos

import SearchLight: AbstractModel, DbId
import Base: @kwdef

export Todo

@kwdef mutable struct Todo <: AbstractModel
  id::DbId = DbId()
  todo::String = ""
  completed::Bool = false
end

end
```

Let's give our model a try:

```julia
julia> using Todos
```

We'll ask SearchLight to find all the todos:

```
julia> all(Todo)
```

Output:

```
[ Info: 2022-05-29 12:58:03 SELECT "todos"."id" AS "todos_id", "todos"."todo" AS "todos_todo", "todos"."completed" AS "todos_completed" FROM "todos" ORDER BY todos.id ASC
Todo[]
```

Since we haven't added any todo item we're getting back an empty vector of Todo objects.

Time to create our first todo:

```julia
julia> my_first_todo = Todo()
```

We've just created our first todo item:

```
Todo
| KEY             | VALUE |
|-----------------|-------|
| completed::Bool | false |
| id::DbId        | NULL  |
| todo::String    |       |
```

However, this is empty, so not very useful. We should store something useful in it:

```julia
julia> my_first_todo.todo = "Build the Genie TodoMVC app"
```

Now, to store it, run:

```
julia> save!(my_first_todo)
```

Output:

```
[ Info: INSERT  INTO todos ("todo", "completed") VALUES ('Build the Genie TodoMVC app', false)
[ Info: SELECT CASE WHEN last_insert_rowid() = 0 THEN -1 ELSE last_insert_rowid() END AS LAST_INSERT_ID
[ Info: SELECT "todos"."id" AS "todos_id", "todos"."todo" AS "todos_todo", "todos"."completed" AS "todos_completed" FROM "todos" WHERE "id" = 1 ORDER BY todos.id ASC

Todo
| KEY             | VALUE                       |
|-----------------|-----------------------------|
| completed::Bool | false                       |
| id::DbId        | 1                           |
| todo::String    | Build the Genie TodoMVC app |
```

The `save!` function will persist the todo data to the database, modifying our todo object by setting its `id` field to the row id that was retrieved from the database operation. If the database operation fails, an exception is thrown.

SearchLight is smart and runs the correct queries, depending on context: in this case it generated an `INSERT` query to add a new row -- but when changing an object that already has data loaded from the database, it will generate an `UPDATE` query instead. Let's see it in action.

```julia
julia> save!(my_first_todo)
```

Output

```
[ Info: UPDATE todos SET  "id" = '1', "todo" = 'Finish my first Genie app', "completed" = false WHERE todos.id = '1' ; SELECT 1 AS LAST_INSERT_ID
[ Info: SELECT "todos"."id" AS "todos_id", "todos"."todo" AS "todos_todo", "todos"."completed" AS "todos_completed" FROM "todos" WHERE "id" = 1 ORDER BY todos.id ASC

Todo
| KEY             | VALUE                     |
|-----------------|---------------------------|
| completed::Bool | false                     |
| id::DbId        | 1                         |
| todo::String    | Finish my first Genie app |
```

We are now done setting up the database interaction layer (the Model layer). Next we'll discuss the View and the Controller layers of our Genie Todo MVC application.

## Controller and views

In MVC applications, the views format and display the data (from the model layer) to the user. However, the views do not interact directly with the model layer. Instead, they interact with the controller layer. The controller layer is responsible for handling user input and updating the model data as well. Every time a web request is made to the server, first the controller is invoked, reading and/or modifying the model data. This model data is then passed to the view layer, which formats and displays the data to the user. Let's see this in action in our app.

Genie's generator will create a controller for us:

```julia
julia> Genie.Generator.newcontroller("Todo")
```

The controller file is in the same location as our model, as indicated by the output:

```
[ Info: New controller created at TodoMVC/app/resources/todos/TodosController.jl
```

Let's add logic to display all the todos. We'll start by adding a function (let's call it `index`) that retrieves all the todos from the database and renders them to the user.

```julia
module TodosController

using TodoMVC.Todos
using Genie.Renderers, Genie.Renderers.Html

function index()
  html(:todos, :index; todos = all(Todo))
end

end
```

It's as simple as this: we retrieve all the todo items using the `all` function from SearchLight, and pass them to the `index` view, within the `todos` resource folder.

Time to add a simple view file - create the `app/resources/todos/views` folder and create a `index.jl.html` file:

```julia
julia> mkdir("app/resources/todos/views")
julia> touch("app/resources/todos/views/index.jl.html")
```

Genie supports a variety of languages for views, including pure Julia, Markdown, and HTML with embedded Julia. Our `index.jl.html` file will be written mostly with HTML, and we'll use Julia language constructs (`if`, `for`, etc) and Julia variables interpolation to make the output dynamic.

Now, edit the `index.jl.html` file and add the following code:

```html
<% if isempty(todos) %>
  <p>Nothing to do!</p>
<% else %>
  <ul>
    <% for_each(todos) do todo %>
      <li>
        <input type="checkbox" checked="$(todo.completed ? true : false)" />
        <label>$(todo.todo)</label>
      </li>
    <% end %>
  </ul>
<% end %>
```

In the HTML code above we use a series of Julia language constructs to dynamically generate the HTML. The `if` statement checks if the todos vector is empty, and if so, displays a message to the user. Otherwise, it iterates over the todos vector and displays each todo item. Julia code blocks are delimited by `<% %>` tags, while for outputting values we resort to the `$(...)` syntax for string interpolation. Also notice the use of the `for_each` function - this is a helper provided by Genie to iterate over a collection and automatically concatenate the output of the loop and render it into the view.

We're almost ready to view our todos on the web. But there is one thing missing: we need to register a _route_ - that is, a mapping between a URL that will be requested by the users and the (controller) function that will return the response. Let's add a route to our app. Edit the `routes.jl` file inside the top `TodoMVC` folder and edit it to look like this:

```julia
using Genie
using TodoMVC.TodosController

route("/", TodosController.index)
```

Now we can access our todos at `http://localhost:8000/` - and we should see the one todo item we previously created.

### The layout file

When rendering a view file, by default, it is automatically wrapped by a layout file. The role of the layout is to render generic UI elements that are present on multiple pages, such as the main navigation or the footer. The default layout file is located in the `app/layouts` folder, and it is called `app.jl.html`. Let's use it to style our todos a bit.

Edit the `app.jl.html` file and make it look like this

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Genie Todo MVC</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet">
  </head>
  <body>
    <div class="container">
      <h1>What needs to be done?</h1>
      <%
        @yield
      %>
    </div>
  </body>
</html>
```

Arguably one of the most important elements of the layout file is the `@yield` macro. This is a special macro that is used to render the content of the view file. In the above example, the `@yield` macro is used to render the content of the `index.jl.html` file.

We have included the `bootstrap` library in our `app.jl.html` file. This library provides a lot of useful styles and components for our todo app and we'll use some of them in our view. We've added a div with the class `container` to make our layout responsive and centered. We also have a `h1` element to display the title of our app.

Next, make sure that the `index.jl.html` file is updated as follows:

```html
<% if isempty(todos) %>
  <p>Nothing to do!</p>
<% else %>
  <div class="row">
    <ul class="list-group">
      <% for_each(todos) do todo %>
        <li class="list-group-item form-check form-switch">
          <input type="checkbox" checked="$(todo.completed ? true : false)" class="form-check-input" id="todo_$(todo.id)"  value="(todo.id)" />
          <label class="form-check-label" for="todo_$(todo.id)">$(todo.todo)</label>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

Our todo list looks much better already!

### View partials

Genie provides yet another feature for building complex views. View partials are small pieces of code that can be reused in multiple views. Let's add a view partial to our app that contains a form for creating new todos. We'll create this file in the `app/resources/todos/views` folder and name it `_form.jl.html`.

```julia
julia> touch("app/resources/todos/views/_form.jl.html")
```

We can now add the following content to the `_form.jl.html` file:

```html
<div class="row">
  <form method="POST" action="/todos">
    <div class="input-group mb-3">
      <input type="text" class="form-control" placeholder="Add a new todo">
      <input type="submit" class="btn btn-outline-secondary" value="Add">
    </div>
  </form>
</div>
```

We are adding a form with one text input for entering the new todo item and a submit button. In order to include the partial into our view, we'll use the `partial` function. Add the following code at the end of the `index.jl.html` file:

```html
<% partial("app/resources/todos/views/_form.jl.html") %>
```

In order for our form to work as expected, we need to add the corresponding route and the controller function. To add the route, edit the `routes.jl` file and add the following code:

```julia
route("/todos", TodosController.create, method = POST)
```

And for the controller function, edit the `TodosController.jl` file and add the following code:

```julia
using Genie.Router
using SearchLight

function create()
  todo = Todo(todo = params(:todo))

  if save(todo)
    redirect("/?success=Todo created")
  else
    redirect("/?error=Could not save todo&todo=$(params(:todo))")
  end
end
```

In the above code, after adding a few extra `using` statements that give us access to the `redirect` and the `save` methods, we create a new `Todo` object and save it to the database. If the save operation succeeds, we redirect the user to the index page with a success message. Otherwise, we redirect the user to the index page with an error message and the current todo item, to fill up the new todo field with the todo's description.

Let's now add the extra code to the frontend. First, to handle success and error messages in the `index.jl.html` file. Let's add another view partial to handle the messages. Add this on the very first line of `index.jl.html`:

```html
<% partial("app/resources/todos/views/_messages.jl.html") %>
```

Now, create the file with `julia> touch("app/resources/todos/views/_messages.jl.html")` and edit it as follows:

```html
<% if ! isempty(params(:success, "")) %>
  <div class="alert alert-success" role="alert">
    <% params(:success) %>
  </div>
<% elseif ! isempty(params(:error, "")) %>
  <div class="alert alert-danger" role="alert">
    <% params(:error) %>
  </div>
<% else %>
  <br/>
<% end %>
```

In the `_messages.jl.html` partial, we are checking if there is a `:success` parameter in the query string. If there is, we display a success message. Otherwise, we check if there is a `:error` parameter in the query string. If there is, we display an error message. Otherwise, we display nothing.

Finally, in the `_form.jl.html` file, we need to update the input tag to automatically display the todo item that the user entered. Replace the line where the text input tag is defined with the following code (we've added the `value` attribute at the end):

```html
<input type="text" class="form-control" placeholder="Add a new todo" name="todo" value='$(params(:todo, ""))' />
```

Notice that we're using `'` single quotes for the `value` attribute as we're using double quotes inside it.

## Adding validation

So far everything looks great - but, there is a problem. Our application allows users to create new todos, but they can create empty todos -- which is not very useful. We need to add some validation to our application to prevent users from creating empty todos.

Validations are performed by model validators. They represent a collection of validation rules that are applied to a model's data. The `TodosValidator.jl` file should already be included in our application as it was created together with the model. If we open it, we'll see that it already includes a few common validation rules, including a `not_empty` rule.

```julia
function not_empty(field::Symbol, m::T, args::Vararg{Any})::ValidationResult where {T<:AbstractModel}
  isempty(getfield(m, field)) && return ValidationResult(invalid, :not_empty, "should not be empty")

  ValidationResult(valid)
end
```

All we need to do is to update our `Todo` model to declare that the `todo` field should be validated by the `not_empty` rule. Add the following code to the `Todos.jl` model file:

```julia
using SearchLight
using TodoMVC.TodosValidator
import SearchLight.Validation: ModelValidator, ValidationRule

SearchLight.Validation.validator(::Type{Todo}) = ModelValidator([
  ValidationRule(:todo, TodosValidator.not_empty)
])
```

Now, in the `TodosController.jl` file, we modify the `create` function to enforce validations:

```julia
using SearchLight
using SearchLight.Validation

function create()
  todo = Todo(todo = params(:todo))

  validator = validate(todo)
  if haserrors(validator)
    return redirect("/?error=$(errors_to_string(validator))")
  end

  if save(todo)
    redirect("/?success=Todo created")
  else
    redirect("/?error=Could not save todo&todo=$(params(:todo))")
  end
end
```

Now the application will no longer allow the creation of empty todo items.

## Updating todos

The most satisfying part of having a todo list, is marking the items as completed. As it is right now, the application allows us to toggle the completed status of a todo item, but the change is not persisted to the database. Let's fix this.

First let's add a new route and the associated controller function to allow us to toggle the completed status of our todo items. Add the following code to the `routes.jl` file:

```julia
route("/todos/:id::Int/toggle", TodosController.toggle, method = POST)
```

Notice the `:id::Int` component of the route. This is a dynamic route that will contain the id of the todo item that we want to toggle. Also, the route only matches integer values, making sure that incorrect values can not be passed to the controller function.

Now, for the controller function, edit the `TodosController.jl` file and add the following code:

```julia
using Genie.Renderers.Json

function toggle()
  todo = findone(Todo, id = params(:id))
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  todo.completed = ! todo.completed

  save(todo) && json(:todo => todo)
end
```

In the `toggle` function we are finding the todo item with the given id. If the todo item is not found, we return an error page. Otherwise, we toggle the completed status of the todo item and save it to the database, before returning the todo's data as json.

### Enhancing our app with custom JavaScript and CSS

The reason for returning a JSON response from the `toggle` function is that we want to update the todo item in the browser without reloading the page, by using JavaScript to make an AJAX request and then consume the response data in JavaScript. The simplest way to achieve this is by returning a JSON response which can be easily parsed by our JS code. The `json` function is a helper function (available in the `Genie.Renderers.Json` module) that will return a JSON response with the given data. Let's see how we can enhance our app with custom JavaScript!

For making the AJAX request we'll use a library called Axios (<https://axios-http.com>). First, we'll load the script from the CDN, by adding this tag to our layout file (`app/layouts/app.jl.html`) right above the closing `</body>` tag:

```html
<script src="https://unpkg.com/axios/dist/axios.min.js"></script>
```

While we're at it, let's also include Cash.js, a very small utility library that makes manipulating the DOM a breeze (<https://github.com/fabiospampinato/cash>). Again, let's load it right above the closing `</body>` tag:

```html
<script src="https://cdn.jsdelivr.net/npm/cash-dom@8.1.1/dist/cash.min.js"></script>
```

We also need to create and include an extra JavaScript file where we will put our own code. Any file that we place inside the `public/` folder, in the root of our app, will be available to include in our HTML views. We'll create a new file called `app.js` in `public/js/` (`julia> touch("public/js/app.js")`) and we'll add it to our layout file (you guessed it, also right before the closing `</body>` tag):

```html
<script src="/js/app.js"></script>
```

Edit the file and put this in:

```js
$(function() {
  $('input[type="checkbox"]').on('change', function() {
    if ( this.checked) {
      $(this).siblings('label').addClass('completed');
    } else {
      $(this).siblings('label').removeClass('completed');
    }
  });
})
```

In addition, we'll add a CSS file to our app (`julia> touch("public/css/app.css")`), right before the closing `</head>` tag in our layout file.

Let's start with the custom CSS, and use it to style our todo items. Add the following code to the `app.css` file:

```html
<link href="/css/app.css" rel="stylesheet" />
```

Then edit the `app.css` file and add the following CSS rules:

```css
.completed {
  text-decoration: line-through;
  color: #d9d9d9;
}
```

Now refresh the page with the todo list and toggle the checkboxes - you should see how the todo items are styled when they are marked as completed. However, the actual state of the todo items is not persisted to the database yet. Add the following code snippet to the `app.js` file to perform a POST request via AJAX to the `/todos/:id/toggle` route and update the todo item's completed status:

```js
$(function() {
  $('input[type="checkbox"]').on('change', function() {
    axios({
      method: 'post',
      url: '/todos/' + $(this).attr('value') + '/toggle',
      data: {}
    })
    .then(function(response) {
      $('#todo_' + response.data.id.value).first().checked = response.data.completed;
    });
  });
});
```

## Updating todo items

Now that we can change the completed status of todo items, we can also allow the users to edit the todo items themselves. We can do this by adding a double click event on our todo items that enable editing mode. Then we capture the `<ENTER>` key to save the changes (while the `<ESC>` key will cancel the changes). Add the following code to the `app.js` file to enable this functionality:

```js
$(function() {
  $('li > label').on('dblclick', function() {
    $(this).attr('contenteditable', true);
  });
  $('li > label').on('keyup', function(event) {
    if (event.keyCode === 13) {
      $(this).removeAttr('contenteditable');
      axios({
        method: 'post',
        url: '/todos/' + $(this).data('todo-id') + '/update',
        data: { todo: $(this).html() }
      })
      .then(function(response) {
        $('label[data-todo-id="' + response.data.id.value + '"]').first().html(response.data.todo);
      });
    } else if (event.keyCode === 27) {
      $(this).removeAttr('contenteditable');
      $(this).text($(this).attr('data-original'));
    }
  });
});
```

In order for the JavaScript code to work, we need to make a modification to our `app/resources/todos/views/index.jl.html` view. Replace the line that adds the `<label>` element with the following:

```html
<label class='form-check-label $(todo.completed ? "completed" : "")' data-original="$(todo.todo)" data-todo-id="$(todo.id)">$(todo.todo)</label>
```

Let's now add a new route and controller function to allow us to update the description of the todo items. Add the following code to the `routes.jl` file:

```julia
route("/todos/:id::Int/update", TodosController.update, method = POST)
```

Then in the `TodosController.jl` file, add the `update` function:

```julia
using Genie.Requests

function update()
  todo = findone(Todo, id = params(:id))
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  todo.todo = replace(jsonpayload("todo"), "<br>"=>"")

  save(todo) && json(todo)
end
```

You'll notice that the function is very similar to the `toggle` function. The only difference is that we are updating the todo item's description instead of its completed status. The value of the `todo` parameter is the value of the `todo` field in the JSON payload which we access through the aptly named function `jsonpayload` provided by the `Genie.Requests` module. In addition we also do some basic input cleaning, by removing any `<br>` tags from the description.

## Deleting todo items

It can be useful to also allow the users to remove todos, either completed or not. We can do this by adding a delete button to each todo item. Update the `index.jl.html` view to add the following code on the line under the `<label>` tag (above the closing `</li>` tag):

```html
<button class="btn btn-outline-danger invisible" type="button" value="$(todo.id)">Delete</button>
```

Next, add the following code to the `app.js` file:

```js
$(function() {
  $('li').on('mouseenter', function() {
    $(this).children('button').removeClass('invisible');
  });
  $('li').on('mouseleave', function() {
    $(this).children('button').addClass('invisible');
  });
  $('li > button').on('click', function() {
    if ( confirm("Are you sure you want to delete this todo?") ) {
      axios({
        method: 'post',
        url: '/todos/' + $(this).attr('value') + '/delete',
        data: {}
      })
      .then(function(response) {
        $('#todo_' + response.data.id.value).first().parent().remove();
      });
    }
  });
});
```

What have we done so far? We have added a new button to each todo item that allows the user to delete the todo item. The button is invisible by default, but when the user hovers over the todo item, the button becomes visible. When the user clicks the button, a confirmation dialog is displayed. If the user confirms, an AJAX request is sent to the `/todos/:id/delete` route to delete the todo item. The response from the server is then used to remove the todo item from the page.

Now, to add the server side logic. First add the following code to the `routes.jl` file:

```julia
route("/todos/:id::Int/delete", TodosController.delete, method = POST)
```

Then in the `TodosController.jl` file, add the `delete` function:

```julia
function delete()
  todo = findone(Todo, id = params(:id))
  if todo === nothing
    return Router.error(NOT_FOUND, "Todo item with id $(params(:id))", MIME"text/html")
  end

  SearchLight.delete(todo)

  json(Dict(:id => (:value => params(:id))))
end
```

The `SearchLight.delete` function removes the todo item from the database and returns the modified todo item, setting its `id` value to `nothing` (to indicate that the object is no longer persisted in the database). However, our frontend needs the todo item's `id` value to be returned so that it can be removed from the page. We can accomplish this by returning the todo item's `id` value in the JSON response.

## Aggregate values and filters

The last piece of functionality of our TodoMVC application, is to allow the users to filter the todo items by their status. We can accomplish this by adding a new toolbar with 3 buttons (representing the 3 possible filters for our list: all, completed, and todo). For each of the buttons, we also want to show a count of the actual number of todos that match the filter.

To keep our view code clean and easy to maintain, we'll create a new view partial to host our new UI elements. Add the following code to the `index.jl.html` view, right at the bottom:

```html
<% partial("app/resources/todos/views/_filters.jl.html") %>
```

Now, create the above view partial:

```julia
julia> touch("app/resources/todos/views/_filters.jl.html")
```

Edit the `_filters.jl.html` file and add the following code:

```html
<div class="btn-group" role="group">
  <a class="btn btn-outline-primary $(active())" href="/">
    All <span class="badge bg-secondary">$(alltodos)</span>
  </a>
  <a class='btn btn-outline-primary $(active("notdone"))' href="/?filter=notdone">
    Not done <span class="badge bg-secondary">$(notdonetodos)</span>
  </a>
  <a class='btn btn-outline-primary $(active("done"))' href="/?filter=done">
    Completed <span class="badge bg-secondary">$(donetodos)</span>
  </a>
</div>
```

Let's unpack this code. We have 3 `<a>` elements, styled as buttons, and rendered as a toolbar (thanks to the Twitter Bootstrap library we included in our page). Within the HTML code we interpolate a few pieces of Julia code that make our output dynamic. That is, for each button, we invoke a function called `active` which adds an "active" CSS class if the button matches the active filter. And within each button, inside the nested `<span>` tag, we interpolate the number of todos that match the filter.

As such, we need to make sure that these values are defined and available in the view layer. We can do this by adding the following code to the `TodosController.jl` file (update the `index` function to look like this and add the extra `using` statement):

```julia
using TodoMVC.ViewHelper

function index()
  notdonetodos = count(Todo, completed = false)
  donetodos = count(Todo, completed = true)
  alltodos = notdonetodos + donetodos

  todos = if params(:filter, "") == "done"
    find(Todo, completed = true)
  elseif params(:filter, "") == "notdone"
    find(Todo, completed = false)
  else
    all(Todo)
  end

  html(:todos, :index; todos, notdonetodos, donetodos, alltodos, ViewHelper.active)
end
```

In the above snippet we use `SearchLight.count` to run a `count` query against the database, matching the filters from the request `params`. We also reference a new module, `TodoMVC.ViewHelper` and pass `ViewHelper.active` into the view, together with all the count values that we computed. In an MVC application, helpers are modules that bundle functions which are used in the view layer, in order to keep the view code DRY and simple. In order for our code to work, we need to define the new module and the `active` function.

First, create the helper file:

```julia
julia> touch("app/helpers/ViewHelper.jl")
```

Next, edit it and add the following code:

```julia
module ViewHelper

using Genie

function active(filter::String = "")
  params(:filter, "") == filter ? "active" : ""
end

end
```

The `active` function is pretty simple. It takes a single optional argument, `filter`. If this matches the current GET request's `filter` parameter, the function returns the string "active", which adds the background color to the button.

## Adding tests to our application

