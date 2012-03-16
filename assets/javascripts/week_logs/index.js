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
    var rStart = new Date(start);
    var rEnd = new Date(start);
    rStart.setDate(rStart.getDate()+1);
    rEnd.setDate(rEnd.getDate()+6)
    var start_output = (rStart.getMonth()+1)+"/"+rStart.getDate()+"/"+rStart.getFullYear();
    var end_output = (rEnd.getMonth()+1)+"/"+rEnd.getDate()+"/"+rEnd.getFullYear();
    var maxDate = new Date(currentYear, currentMonth, currentDate);
    $('#week_start').val(start_output);
    $('#week_end').val(end_output);
    $('#week_selector').val(start_output+" to "+end_output);
    $('#js_week_start').val(rStart);
    $('#js_week_end').val(rEnd);
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
        var rStart = new Date(start);
        var rEnd = new Date(start);
        rStart.setDate(rStart.getDate()+1);
        rEnd.setDate(rEnd.getDate()+6)
        var start_output = (rStart.getMonth()+1)+"/"+rStart.getDate()+"/"+rStart.getFullYear();
        var end_output = (rEnd.getMonth()+1)+"/"+rEnd.getDate()+"/"+rEnd.getFullYear();
        $('#week_start').val(start_output);
        $('#week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
        $('#js_week_start').val(rStart);
        $('#js_week_end').val(rEnd);
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
      var rStart = new Date(start);
      rStart.setDate(rStart.getDate()+1);
      $(id).find('tr.issue').each(function() {
        issue = this.id.match(/\d+/);
        row[issue] = {}
        $(this).find('td.date').each(function(y){
          var inspec = new Date(rStart);
          inspec.setDate(inspec.getDate()+y);
          var row_date = (inspec.getMonth()+1)+'/'+(inspec.getDate())+'/'+inspec.getFullYear();
          row[issue][row_date] = {hours:$(this).find('input').val()};
        });
      });
      return row;
    }

    $("#submit_button").live("click", function(){
      var button = $(this);
      $('#ajax-indicator').show();
      button.attr('disabled', true);
      $.post("/week_logs/update", {
                  project: JSON.stringify(createJsonObject("#proj_table")),
                  non_project: JSON.stringify(createJsonObject("#non_proj_table"))
      })
      .complete(function() { button.attr('disabled', false) })
      .success(function() { Week.repopulateTable() });
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
    var hours = Week.parseHours(this.value), min = 0, max = 24, step = 0.5;
    switch(e.which) {
      case 38: // up
        if(hours + step <= max)
          this.value = parseFloat(hours + step);
        else
          this.value = max;
        this.value = parseFloat(this.value).toFixed(1);
        this.select();
        break;
      case 40: // down
        if(hours - step >= min)
          this.value = parseFloat(hours - step);
        else
          this.value = min;
        this.value = parseFloat(this.value).toFixed(1);
        this.select();
        break;
    }
  }).live('change keyup', function() {
    var row = $(this).parents('.issue'),
      dateFields = row.find('.date').find('input'),
      totalField = row.find('.total'),
      total = 0, i, hours;
    for(i = 0; length = dateFields.length, i < length; i++) {
      hours = dateFields[i].value;
      total += Week.parseHours(hours);
    }
    totalField.val(total.toFixed(1));
    Week.refreshTotalHours();
  }).live('blur', function() {
    var hours = this.value;
    if(!Week.isHours(hours)) {
      this.value = parseFloat(/\d+/.test(this.value) ? this.value.match(/\d+/)[0] : 0).toFixed(1);
    }
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
    var days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    while(inspect <= maxDate) {
      $('th.' + days[i]).html(days[i].capitalize() + '<br />' + inspect.getDate());
      flag == true ? $('.' + days[i]).hide() : $('.' + days[i]).show();
      if(inspect.toDateString() == end.toDateString())
        flag = true;
      i++;
      inspect.setDate(inspect.getDate()+1);
    }
      var inputs = document.getElementsByTagName("input");
		for (var i = 0; i < inputs.length; i++ ) {
			if(inputs[i].type == "text") {
				inputs[i].valueHtml = inputs[i].value;
				inputs[i].onblur = function () {
					if(this.value == "") {
						this.value = this.valueHtml;
					}

				}


			}
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
        $('#success_message').text('Successfully added task #' + taskId + '.').removeClass('hidden');
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
          total += Week.parseHours($(this).val());
        });
        textField.val(total.toFixed(1));
        if(total > 24){alert("Cannot log more than 24 hours per day");}
    });
    var nonProjDailyTotals = $('#non_proj_table').find("input.daily");
    nonProjDailyTotals.each(function(i, el) {
      var textField = $(this);
      var total = 0.0;
      var hoursDay = $("#non_proj_table").find("input."+textField.attr("summary"));
        hoursDay.each(function(i, el) {
          total += Week.parseHours($(this).val());
        });
        textField.val(total.toFixed(1));
        if(total > 24){alert("Cannot log more than 24 hours per day");}
    });
  };

  Week.parseHours = function(hours) {
    // ported from Rails Redmine Core
    hours = hours.trim();
    if(hours.length > 0) {
      if(/^(\d+([.,]\d+)?)h?$/.test(hours)) {
        hours = hours.match(/\d+([.,]\d+)?/)[0];
      } else {
        hours = hours.replace(/^(\d+):(\d+)$/, function(str, h, m) { return parseInt(h) + parseInt(m) / 60.0; });
        hours = hours.replace(/^((\d+)\s*(?:h|hours))?\s*((\d+)\s*(m|min)?)?$/, function(str, hgrp, h, mgrp, m) { return ((hgrp || mgrp) ? (parseInt(h || 0) + parseInt(m || 0) / 60.0) : str[0]); });
      }
      hours = hours.replace(',', '.');
    }
    return parseFloat(hours.length == 0 || isNaN(hours) ? 0 : hours);
  };

  Week.isHours = function(hours) {
    return /^(\d+([.,]\d+)?h?|\d+:\d+|(\d+\s*(h|hours))?\s*(\d+\s*(m|min)?)?)$/.test(hours);
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
        table = row.parents('table'),
        taskId = row.attr('id').replace(/\D+/g, '');
      row.remove();
      Week.refreshTableRowColors(table);
      Week.refreshTotalHours();
      Week.refreshTabIndices();
      $.post('/week_logs/remove_task.js', {id: taskId}).success(function() {
        $('#success_message').text('Successfully removed task #' + taskId + '.').removeClass('hidden');
      });

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
