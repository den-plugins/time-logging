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
        var orig = new Date(start);
        $(this).find('td.date').each(function(y){
          var inc = new Date(start);
          inc.setDate(inc.getDate()+y+1)
          if(y==6)
            var row_date = (orig.getMonth()+1)+'/'+(orig.getDate())+'/'+orig.getFullYear();
          else
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

  $(".hide-button").live("click", function(){
    var title = 'Remove Task';
    if($(this).hasClass('proj'))
      title = 'Remove Project Related Task';
    else if($(this).hasClass('non_proj'))
      title = 'Remove Non-Project (Admin) Related Task';

    $("#dialog-remove-task").dialog('option', 'title', title);
    $("#dialog-remove-task").dialog("open");
    var row = $(this).parents('tr');
    row.addClass("selected");
 });

 Week.addTask = {
    openDialog: function(button) {
      var button = $(button),
        form = $('#add-task-form'),
        title = 'Add Task',
        taskType;
      taskType = button.attr('rel');
      form.attr('rel', taskType);

      if(taskType == 'project')
        title = 'Add Project Related Task';
      else if(taskType == 'admin')
        title = 'Add Non-Project (Admin) Related Task';

      $('#dialog-add-task').dialog('option', 'title', title);
      $('#dialog-add-task').dialog('open');
      form.find('#task-id').focus();
      Week.addTask.resetForm();
    },

    resetForm: function() {
      var form = $('#add-task-form');
      form.find('#task-id').val('');
      form.find('.error').addClass('hidden').text('');
    },

    validate: function(form) {
      var taskIdField = form.find('#task-id'),
        taskId = taskIdField.val();
      if(taskId.length === 0) {
        return 'Issue ID is required.';
      } else if(!/^\s*\d+\s*$/.test(taskId)) {
        return 'Issue ID should be a number.';
      } else {
        return true;
      }
    },

    submit: function() {
      var form = $('#add-task-form'),
        taskIdField = form.find('#task-id'),
        taskId = taskIdField.val().trim(),
        taskType = form.attr('rel');
      $.ajax({
        type: 'post',
        url: '/week_logs/add_task.js',
        data: { 'id': taskId, 'type': taskType, 'week_start': $('#week_start').val() },
        success: function() {
          $('#dialog-add-task').dialog('close');
          Week.repopulateTable(taskId);
          Week.refreshTableDates();
        },
        error: function(data) {
          form.find('.error').text(data.responseText).removeClass('hidden');
          taskIdField.focus().select();
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
  $('.head-button').live('click', function() {
    Week.addTask.openDialog(this);
  });
  $('#add-task-form')
  .attr('action', '')
  .live('submit', function(e) {
    var form = $(this),
      validOrError = Week.addTask.validate(form),
      table = $('#' + form.attr('data-table'));
    e.preventDefault();
    if(validOrError === true) {
      var existingTaskId = form.find('#task-id').val(),
        existingTask = $('#issue-' + existingTaskId);
      form.find('.error').addClass('hidden').text('');
      if(existingTask.length > 0) {
        $('#dialog-add-task').dialog('close');
        existingTask.removeClass('hidden');
        $('html, body').animate({scrollTop: existingTask.offset().top}, 1000, function() {
          if(existingTask.effect) {
            existingTask.effect('highlight');
          }
        });
      } else {
        Week.addTask.submit();
      }
      Week.addTask.resetForm();
    } else {
      form.find('.error').text(validOrError).removeClass('hidden');
    }
    return false;
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
    var projDailyTotals = $('#proj_table').find("input.daily");
    projDailyTotals.each(function(i, el) {
      var textField = $(this);
      var total = 0.0;
      var hoursDay = $("#proj_table").find("input."+textField.attr("summary"));
        hoursDay.each(function(i, el) {
          total += parseFloat($(this).val());
        });
        textField.val(total.toFixed(1));
    });
    var nonProjDailyTotals = $('#non_proj_table').find("input.daily");
    nonProjDailyTotals.each(function(i, el) {
      var textField = $(this);
      var total = 0.0;
      var hoursDay = $("#non_proj_table").find("input."+textField.attr("summary"));
        hoursDay.each(function(i, el) {
          total += parseFloat($(this).val());
        });
        textField.val(total.toFixed(1));
    });
  };

  $("#dialog-remove-task").dialog({
    autoOpen: false,
    width: 300,
    resizable: false,
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
      $.post('/week_logs/remove_task.js', {id: row.attr('id').replace(/\D+/g, '')});

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

  $("#dialog-add-task").dialog({
    autoOpen: false,
    width: 300,
    modal: true,
    resizable: false,
    title: 'Add Task',
    buttons: {
      "Add": function() {
        $('#add-task-form').submit();
      },
      "Cancel": function() {
        $(this).dialog("close");
      }
    },
    close: function(ev, ui) {
      Week.addTask.resetForm($('#add-task-form'));
    }
  });
}
