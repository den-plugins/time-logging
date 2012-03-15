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
    var start = new Date(current_date.getFullYear(), current_date.getMonth(), current_date.getDate() - current_date.getDay());
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
    Week.refreshTotalHours();
    Week.refreshTabIndices();
    $('#week_selector').datepicker({
      maxDate: maxDate,
      showOn: "button",
      buttonImage: "",
      firstDay: 7,
      onSelect: function(select_date) {
        var sd = $(this).datepicker('getDate');
        start = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay());
        end = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay() + 6);
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
      $(id).find('tr.issue').each(function() {
        issue = this.id.match(/\d+/);
        row[issue] = {}
        $(this).find('td.date').each(function(y){
          var inc = new Date(start);
          inc.setDate(inc.getDate()+y)
          var row_date = (inc.getMonth()+1)+'/'+(inc.getDate())+'/'+inc.getFullYear();
          row[issue][row_date] = {hours:$(this).find('input').val()};
        });
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

  $(".hide-button.proj").live("click", function(){
    $("#dialog-remove-task").dialog('option', 'title', 'Remove Project Related Task');
    $("#dialog-remove-task").dialog("open");
    var row = $(this).parents('tr');
    row.addClass("selected");
 });

 $(".hide-button.non_proj").live("click", function(){
    $("#dialog-remove-task").dialog('option', 'title', 'Remove Non-Project (Admin) Related Task');
    $("#dialog-remove-task").dialog("open");
    var row = $(this).parents('tr');
    row.addClass("selected");
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
      var table = $('#' + form.attr('data-table')),
        id = form.find('.add-task-id').val().trim();
      $.ajax({
        type: 'post',
        url: '/week_logs/add_task',
        data: form.serialize() + '&' + $('#week_start').serialize(),
        success: function() {
          Week.repopulateTable(id);
          Week.refreshTableDates();
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

  $('.date input').live('focus', function() {
    this.select();
  }).live('keydown', function(e) {
    // mimic html5 number field behavior
    var hours = this.value, min = 0, max = 24, step = 0.5;
    hours = parseFloat(hours.length == 0 || isNaN(hours) ? 0 : hours);
    switch(e.which) {
      case 38: // up
        if(hours + step <= max)
          this.value = parseFloat(hours + step).toFixed(1);
        else
          this.value = max.toFixed(1);
        break;
      case 40: // down
        if(hours - step >= min)
          this.value = parseFloat(hours - step).toFixed(1);
        else
          this.value = min.toFixed(1);
        break;
    }
    this.select();
  }).live('change keyup', function() {
    var row = $(this).parents('.issue'),
      dateFields = row.find('.date').find('input'),
      totalField = row.find('.total'),
      total = 0, i, hours;
    for(i = 0; length = dateFields.length, i < length; i++) {
      hours = dateFields[i].value;
      total += parseFloat(hours.length == 0 || isNaN(hours) ? 0 : hours);
    }
    totalField.val(total.toFixed(1));
    Week.refreshTotalHours();
  }).live('blur', function() {
    var hours = this.value;
    this.value = parseFloat(hours.length == 0 || isNaN(hours) ? 0 : hours).toFixed(1);
  });
  $('.head-button, .add-task-cancel').live('click', function() {
    Week.addTask.toggleForm(this);
  });
  $('.add-task-form')
  .attr('action', '')
  .live('submit', function(e) {
    var form = $(this),
      submitButton = form.find('.add-task-submit'),
      validOrError = Week.addTask.validate(form),
      table = $('#' + form.attr('data-table'));
    e.preventDefault();
    if(submitButton.is(':disabled')) {
      return false;
    }
    if(validOrError === true) {
      var taskTableBody = table.find('tbody'),
        existingTaskId = form.find('.add-task-id').val(),
        existingTask = taskTableBody.find('#issue-' + existingTaskId);
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
      submitButton.attr('disabled', true);
      form.find('.add-task-id').val('');
      Week.refreshTableRowColors(table);
    } else {
      form.find('.error').text(validOrError).removeClass('hidden');
    }
    return false;
  })
  .find('.add-task-id')
  .live('change keyup', function() {
    var submitButton = $(this).siblings().find('.add-task-submit');
    submitButton.attr('disabled', $(this).val().length == 0 || /\D+/.test($(this).val()));
  });

  Week.refreshTableDates = function() {
    var start = new Date($("#js_week_start").val());
    var end = new Date($("#js_week_end").val());
    var inspect = new Date(start);
    var i = 0;
    var flag = false;
    var maxDate = new Date(inspect.getFullYear(), inspect.getMonth(), inspect.getDate() - inspect.getDay() + 6);
    var days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    while(inspect <= maxDate) {
      $('th.' + days[i]).html(days[i].capitalize() + '<br />' + inspect.getDate());
      flag == true ? $('.' + days[i]).hide() : $('.' + days[i]).show();
      if(inspect.toDateString() == end.toDateString())
        flag = true;
      i++;
      inspect.setDate(inspect.getDate()+1);
    }
  };

  Week.repopulateTable = function(taskId) {
    var href = "/week_logs?", taskRow;
    href+="&week_start="+$("#week_start").val();
    $('#ajax-indicator').show();
    $.getScript(href, function() {
      Week.refreshTotalHours();
      Week.refreshTableDates();
      Week.refreshTabIndices();
      $('#ajax-indicator').hide();
      if(taskId && taskId.length > 0) {
        taskRow = $('#issue-' + taskId);
        if(taskRow.length > 0) {
          $('html, body').animate({scrollTop: taskRow.offset().top}, 1000, function() {
            if(taskRow.effect) {
              taskRow.effect('highlight');
            }
          });
        }
      }
    });
  }

  Week.refreshTableRowColors = function(table) {
    var rows = table.find('tbody').find('tr.issue').not('.hidden'), i;
    for(i = 0; length = rows.length, i < length; i++) {
      $(rows[i]).removeClass('odd even').addClass(i % 2 != 0 ? 'even' : 'odd');
    }
  };

  Week.refreshTabIndices = function() {
    var rows = $('tr.issue').not('.hidden'), cells, i, j;
    for(i = 0; length = rows.length, i < length; i++) {
      cells = $(rows[i]).find('td.date').not(':hidden').find('input');
      for(j = 0; sublength = cells.length, j < sublength; j++) {
        cells[j].tabIndex = (i * 7) + (j + 1);
      }
    }
    document.getElementById('submit_button').tabIndex = (i * 7) + (j + 1);
  };

  Week.refreshTotalHours = function() {
    var projTotal = 0, nonProjTotal = 0,
      issueTotals = $('#proj_table').find('input.total');
    issueTotals.each(function(i, el) {
      projTotal += parseFloat(el.value);
    });
    $('#total_proj').val(parseFloat(projTotal).toFixed(1));
    issueTotals = $('#non_proj_table').find('input.total');
    issueTotals.each(function(i, el) {
      nonProjTotal += parseFloat(el.value);
    });
    $('#total_non_proj').val(parseFloat(nonProjTotal).toFixed(1));
    $('#total_hours').val(parseFloat(projTotal + nonProjTotal).toFixed(1));
  };

  $("#dialog-remove-task").dialog({
              autoOpen: false,
              height: 150,
              width: 450,
              modal: true,
              buttons: {
                  "Yes": function() {
                  var bValid = true;
                  var row = $("tr.selected"),
                  table = row.parents('table');
                  row.remove();
                  Week.refreshTableRowColors(table);
                  Week.refreshTotalHours();
                  Week.refreshTabIndices();
                  $.post('/week_logs/remove_task', {id: row.attr('id')});

                  if (bValid) {
                      //If valid execute script and close the dialog.
                      $(this).dialog("close");
                  }
              },
                  "No": function() {
                    $(this).dialog("close");
                  }
              },
              close: function(ev, ui) {
                var row = $("tr.selected");
                row.removeClass("selected");
              }
          });
}