$(function() {
  $('input[type="checkbox"]').on('change', function() {
    if ( this.checked) {
      $(this).siblings('label').addClass('completed');
    } else {
      $(this).siblings('label').removeClass('completed');
    }
  });
});

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