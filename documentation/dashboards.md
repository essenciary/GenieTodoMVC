# Developing interactive data dashboards with Genie

Julia is a relatively new programming language, but it has already gained a lot of traction in the data science community. It is designed to be easy to learn and use, and has seen great adoption in digital R&D, scientific computing, data analysis and machine learning. A critical part of the data science workflow is the ability to create interactive data dashboards for data exploration and analysis. In this chapter, we will see how to use the [Genie](https://genieframework.com) framework to create interactive data dashboards.

We will extend our todo app with a new section that will allow us to analyze and visualize our todo list to understand how our time is allocated between various types of activities. However, as it is right now, our data is not very useful for this purpose. We need richer data, and a lot more of it in order to do interesting things. So let's add a few more fields to our todo items, and generate a lot of random data.

To make for an interesting analysis, let's add the following fields:

1) category - we'll make this a string with one of the following values: "work", "personal", "family", "hobby", "errands", "shopping", "accounting", "learning", "other"
2) date - the day the todo item was created
3) duration - an integer representing the duration of the todo item in minutes.

And for our data dashboard, we will allow our users to filter the data by category and date interval, and visualize the todo data by date, category and duration, exposing interesting stats about individual todos (like due, overdue, etc) and aggregated stats (such as categories that take the most time or total time by day).

## Augmenting the data

We'll begin by adding the new fields to our todo items. As usual, we'll use a migration, so let's create it:

```julia
julia> using SearchLight
julia> SearchLight.Migrations.new("add category date and duration to todos")
```

Once the migration is created, edit the new migration file as follows:

```julia
module AddCategoryDateAndDurationToTodos

import SearchLight.Migrations: add_columns, remove_columns, add_indices, remove_indices

function up()
  add_columns(:todos, [
    :category => :string,
    :date => :date,
    :duration => :int
  ])

  add_indices(:todos, [
    :category,
    :date,
    :duration
  ])
end

function down()
  remove_indices(:todos, [
    :category,
    :date,
    :duration
  ])

  remove_columns(:todos, [
    :category,
    :date,
    :duration
  ])
end

end
```

When ready, run the migration to update the database schema:

```julia
julia> SearchLight.Migrations.up()
```

Now that we have the new fields in our database, we need to update our todo model to reflect the new fields. Update the
`app/resources/todos/Todos.jl` file by replacing the declaration of the `Todo` struct with the following:

```julia
using Dates

const CATEGORIES = ["work", "personal", "family", "hobby", "errands", "shopping", "accounting", "learning", "other"]

@kwdef mutable struct Todo <: AbstractModel
  id::DbId = DbId()
  todo::String = ""
  completed::Bool = false
  user_id::DbId = DbId()
  category::String = CATEGORIES[end]
  date::Date = Dates.today()
  duration::Int = 30
end
```

For start we have added a new dependency on the `Dates` module, as our new `date` properties is a date instance. This means that
we also need to declare the dependency in our `Project.toml` file, so make sure to run `pkg> add Dates` in the app's repl. We also
define a `CATEGORIES` constant where we stored the list of possible categories. We then update the `Todo` struct to include the new fields,
setting their default values to the last category in the list ("other"), today's date and 30 minutes.

### Generating random data

Now that our database and model definition have been updated, we need to generate some random data to populate our database and make
our dashboard more interesting. We also need to set some random values for the new columns for the todos that already exist in the database.
Let's create a new migration to script and run our data generation:

```julia
julia> using SearchLight
julia> SearchLight.Migrations.new("generate fake todos")
```

In the resulting migration file, add the following code:

```julia
module GenerateFakeTodos

using ..Main.TodoMVC.Todos
using SearchLight
using Dates
using Faker

randcategory() = rand(Todos.CATEGORIES)
randdate() = Dates.today() - Day(rand(0:90))
randduration() = rand(10:240)

function up()
  for i in 1:1_000
    Todo(
      todo = Faker.sentence(),
      completed = rand([true, false]),
      user_id = DbId(1),
      category = randcategory(),
      date = randdate(),
      duration = randduration()
    ) |> save!
  end

  for t in find(Todo, SQLWhereExpression("category is ?", nothing))
    t.category = randcategory()
    date = randdate()
    duration = randduration()
    save!(t)
  end
end

function down()
  throw(SearchLight.Migration.IrreversibleMigrationException(@__MODULE__))
end

end
```

This migration will generate 1000 new todos with random values, and then update the existing todos with more random values
for the new columns. We use the `Faker` package to generate random sentences for the `todo` field, so make sure to add it to the
app file as well (`pkg> add Faker`). For the generation of the random categories, dates, and duration values, we declare
three helper functions (`randcategory`, `randdate`, and `randduration`) that we can reuse to both create new todos and update
the existing ones.

Now you can run the migration to generate the fake data:

```julia
julia> using SearchLight
julia> SearchLight.Migrations.up()
```

## Building our data dashboard

Now that we have a lot more data, we can start building our data dashboard. We'll start by creating a new resource (controller)
for our dashboard:

```julia
julia> using Genie
julia> Genie.Generator.newresource("dashboard", pluralize = false)
```

This will create a new controller file `app/resources/dashboard/DashboardController.jl`.

