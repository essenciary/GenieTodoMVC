Html.div(class="container", [
  row([
    h1("Todos productivity report")
    btn(color="primary", flat=true, "Home", onclick="javascript:window.location.href='/';")
  ])

  row([
    expansionitem(expandseparator = true, icon = "tune", label = "Filters", hidebottomspace = true,
                class="col-12", style="padding: 4px;", [
      Html.div(class="col-6 col-sm-6 col-md-3 col-lg-3 col-xl-3", style="padding: 4px;", [
        textfield("Start date", :filter_startdate, clearable = true, filled = true, [
          icon(name = "event", class = "cursor-pointer", style = "height: 100%;", [
            popup_proxy(cover = true, [datepicker(:filter_startdate, mask = "YYYY-MM-DD")])
          ])
        ])
      ])

      Html.div(class="col-6 col-sm-6 col-md-3 col-lg-3 col-xl-3", style="padding: 4px;", [
        textfield("End date", :filter_enddate, clearable = true, filled = true, [
          icon(name = "event", class = "cursor-pointer", style = "height: 100%", [
            popup_proxy(ref = "qDateProxy", cover = true, [datepicker(:filter_enddate, mask = "YYYY-MM-DD")])
          ])
        ])
      ])
    ])
  ])

  row([ # big numbers row
    cell(class="st-module", [
      row([
        cell(class="st-br", [
          bignumber("Total completed", :total_completed, icon="format_list_numbered", color="positive")
        ])
        cell(class="st-br", [
          bignumber("Total incomplete", :total_incompleted, icon="format_list_numbered", color="negative")
        ])
        cell(class="st-br", [
          bignumber("Total time completed", :total_time_completed, icon="format_list_numbered", color="positive")
        ])
        cell(class="st-br", [
          bignumber("Total time incomplete", :total_time_incompleted, icon="format_list_numbered", color="negative")
        ])
      ])
    ])
  ]) # end big numbers row

  row([
    cell(class="st-module", [
      Html.div(class="col-12", plot(:todos_by_status_number, layout = "{ title: 'Todos by status', xaxis: { title: 'Date' }, yaxis: { title: 'Number of todos' } }"))
    ])
  ])
  row([
    cell(class="st-module", [
      Html.div(class="col-12", plot(:todos_by_status_time, layout = "{ barmode: 'stack', title: 'Todos by status and duration', xaxis: { title: 'Date' }, yaxis: { title: 'Total duration' } }"))
    ])
  ])
  row([
    cell(class="st-module", [
      Html.div(class="col-6", plot(:todos_by_category_complete, layout = "{ title: 'Completed todos by category', xaxis: { title: 'Category' }, yaxis: { title: 'Number of todos' } }"))
    ])
    cell(class="st-module", [
      Html.div(class="col-6", plot(:todos_by_category_incomplete, layout = "{ title: 'Incompleted todos by category', xaxis: { title: 'Category' }, yaxis: { title: 'Number of todos' } }"))
    ])
  ])
])