using Genie
using TodoMVC.TodosController

route("/", TodosController.index)
route("/todos", TodosController.create, method = POST)
route("/todos/:id::Int/toggle", TodosController.toggle, method = POST)
route("/todos/:id::Int/update", TodosController.update, method = POST)
route("/todos/:id::Int/delete", TodosController.delete, method = POST)

route("/api/v1/todos", TodosController.API.V1.list, method = GET)
route("/api/v1/todos/:id::Int", TodosController.API.V1.item, method = GET)
route("/api/v1/todos", TodosController.API.V1.create, method = POST)
route("/api/v1/todos/:id::Int", TodosController.API.V1.update, method = PATCH)
route("/api/v1/todos/:id::Int", TodosController.API.V1.delete, method = DELETE)