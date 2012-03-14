$(document).ready(function(){
  initializers();
  Week.init();
});

function initializers() {
  var date = new Date();
  var currentMonth = date.getMonth();
  var currentDate = date.getDate();
  var currentYear = date.getFullYear();
  if (typeof Week === 'undefined') {
    Week = {};
  }

  Week.init = function() {
    var current_date = new Date();
    var start = new Date(current_date.getFullYear(), current_date.getMonth(), current_date.getDate() - current_date.getDay()+1);
    var end = current_date;
    var start_output = (start.getMonth()+1)+"/"+start.getDate()+"/"+start.getFullYear();
    var end_output = (end.getMonth()+1)+"/"+end.getDate()+"/"+end.getFullYear();
    var maxDate = new Date(currentYear, currentMonth, currentDate);
    $('#week_start').val(start_output);
    $('#week_end').val(end_output);
    $('#week_selector').val(start_output+" to "+end_output);
    $('#js_week_start').val(start);
    $('#js_week_end').val(end);
    Week.refreshTableDates();
    $('#week_selector').datepicker({
      maxDate: maxDate,
      showOn: "button",
      buttonImage: "",
      firstDay: 1,
      onSelect: function(select_date) {
        var sd = $(this).datepicker('getDate');
        start = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay()+1);
        end = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay() + 7);
        if(end > maxDate)
          end = maxDate;
        var start_output = (start.getMonth()+1)+"/"+start.getDate()+"/"+start.getFullYear();
        var end_output = (end.getMonth()+1)+"/"+end.getDate()+"/"+end.getFullYear();
        $('#week_start').val(start_output);
        $('#week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
        $('#js_week_start').val(start);
        $('#js_week_end').val(end);
        Week.repopulateTable();
      },
      beforeShowDay: function(dates) {
          var cssClass = '';
          if(dates >= start && dates <= end)
              cssClass = 'ui-state-highlight ui-state-active';
          return [true, cssClass];
      },
    });
    function createJsonObject(id) {
      var row = {};
      $(id).find("tbody tr").each(function(i) {
        if($(this).attr("class")!="total") {
          issue = $(this).text().match(/\d+/);
          row[issue] = {}
          $(this).find("td.date").each(function(y){
            var inc = new Date(start);
            inc.setDate(inc.getDate()+y)
            var row_date = (inc.getMonth()+1)+"/"+(inc.getDate())+"/"+inc.getFullYear();
            row[issue][row_date] = {hours:$(this).find("input").val()};
          });
        }
      });
      return row;
    }

    $("#submit_button").live("click", function(){
      $.post("/week_logs/update", {
                  project: JSON.stringify(createJsonObject("#proj_table")),
                  non_project: JSON.stringify(createJsonObject("#non_proj_table"))
      })
      .success(function() {Week.repopulateTable();});
    });
  }

  $(".hide-button").live("click", function(){
    var row = $(this).parents('tr'),
      table = row.parents('table');
    row.remove();
    Week.refreshTableRowColors(table);
  });

  Week.addTask = {
    toggleForm: function(button) {
      var button = $(button),
        form = $('#' + button.attr('data-toggle'));
      button = $('#' + form.attr('data-button'));
      if(form.hasClass('hidden')) {
        form.removeClass('hidden');
        form.find('.add-task-id').focus();
        button.addClass('hidden');
      } else {
        form.addClass('hidden');
        button.removeClass('hidden');
      }
      form.find('.add-task-submit').attr('disabled', true);
      form.find('.add-task-id').val('');
      form.find('.error').addClass('hidden').text('');
    },

    row: function(data, table) {
      var taskRow = $(data),
        taskTableBody = $(table).find('tbody'),
        firstTaskRow = taskTableBody.find('tr').first();
      if(firstTaskRow && firstTaskRow.hasClass('even')) {
        taskRow.addClass('odd');
      } else {
        taskRow.addClass('even');
      }
      taskTableBody.append(taskRow);
      return taskRow;
    },

    validate: function(form) {
      var taskIdField = form.find('.add-task-id'),
        taskId = taskIdField.val();
      if(taskId.length === 0) {
        return 'Issue ID is required.';
      } else if(!/^\s*\d+\s*$/.test(taskId)) {
        return 'Issue ID should be a number.';
      } else {
        return true;
      }
    },

    submit: function(form) {
      var table = $('#' + form.attr('data-table'));
      $.ajax({
        type: 'post',
        url: '/week_logs/add_task',
        data: form.serialize() + '&' + $('#week_start').serialize(),
        success: function(data) {
          var taskRow = Week.addTask.row(data, table);
          Week.repopulateTable();
          Week.refreshTableDates();
          $('html, body').animate({scrollTop: taskRow.offset().top}, 1000, function() {
            if(taskRow.effect) {
              taskRow.effect('highlight');
            }
          });
          form.find('input').not('.add-task-submit').attr('disabled', false);
          form.find('.add-task-id').focus();
        },
        error: function(data) {
          form.find('.error').text(data.responseText).removeClass('hidden');
          form.find('input').not('.add-task-submit').attr('disabled', false);
          form.find('.add-task-id').focus();
        },
        beforeSend: function() {
          form.find('input').attr('disabled', true);
        }
      });
    }
  };

  $('.head-button, .add-task-cancel').live('click', function() {
    Week.addTask.toggleForm(this);
  });
  $('.add-task-form')
  .attr('action', '')
  .live('submit', function(e) {
    var form = $(this),
      validOrError = Week.addTask.validate(form),
      table = $('#' + form.attr('data-table'));
    e.preventDefault();
    if(form.find('.add-task-submit').is(':disabled')) {
      return false;
    }
    if(validOrError === true) {
      var taskTableBody = table.find('tbody'),
        existingTaskId = form.find('.add-task-id').val(),
        existingTask = taskTableBody.find('#' + existingTaskId);
      form.find('.error').addClass('hidden').text('');
      if(existingTask.length > 0) {
        existingTask.removeClass('hidden');
        $('html, body').animate({scrollTop: existingTask.offset().top}, 1000, function() {
          if(existingTask.effect) {
            existingTask.effect('highlight');
          }
        });
      } else {
        Week.addTask.submit(form);
      }
      form.find('.add-task-submit').attr('disabled', true);
      form.find('.add-task-id').val('');
      Week.refreshTableRowColors(table);
    } else {
      form.find('.error').text(validOrError).removeClass('hidden');
    }
    return false;
  })
  .find('.add-task-id')
  .live('change keyup', function() {
    var submitButton = $('#' + $(this).attr('data-disable'));
    submitButton.attr('disabled', $(this).val().length == 0 || /\D+/.test($(this).val()));
  });

  Week.refreshTableDates = function() {
    var start = new Date($("#js_week_start").val());
    var end = new Date($("#js_week_end").val());
    var inspect = new Date(start);
    var i = 0;
    var flag = false;
    var maxDate = new Date(inspect.getFullYear(), inspect.getMonth(), inspect.getDate() - inspect.getDay() + 7);
    var days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    while(inspect <= maxDate) {
      $('th.' + days[i]).html(days[i].capitalize() + '<br />' + inspect.getDate());
      flag == true ? $('.' + days[i]).hide() : $('.' + days[i]).show();
      if(inspect.toDateString() == end.toDateString())
        flag = true;
      i++;
      inspect.setDate(inspect.getDate()+1);
    }
  };

  Week.repopulateTable = function() {
    var href = "/week_logs?";
    href+="&week_start="+$("#week_start").val();
    $('#ajax-indicator').show();
    $.getScript(href, function() {
      Week.refreshTotalHours();
      Week.refreshTableDates();
      $('#ajax-indicator').hide();
    });
  }

  Week.refreshTableRowColors = function(table) {
    var rows = table.find('tbody').find('tr').not('.hidden'), i;
    for(i = 0; length = rows.length, i < length; i++) {
      $(rows[i]).removeClass('odd even').addClass(i % 2 != 0 ? 'even' : 'odd');
    }
  };

  Week.refreshTotalHours = function() {
    var total = parseFloat($('#total_proj').val()) + parseFloat($('#total_non_proj').val());
    $('#total_hours').val(parseFloat(total).toFixed(1));
  };
}