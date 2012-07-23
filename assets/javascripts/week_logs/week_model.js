var Week = {
  init: function() {
    var me = this;
    me._today = new Date();
    me._start = new Date(me._today.getFullYear(), me._today.getMonth(), me._today.getDate() - me._today.getDay());
    me._end = new Date();
    Week.updateDateFields();
  },

  updateDateFields: function() {
    var me = this;
    var origin = me._start,
      rStart = new Date(origin.getFullYear(), origin.getMonth(), origin.getDate() + 1),
      rEnd = new Date(origin.getFullYear(), origin.getMonth(), origin.getDate() + 7),
      startOutput = $.datepicker.formatDate('m/d/yy', rStart),
      endOutput = $.datepicker.formatDate('m/d/yy', rEnd);
    $('#week_start').val(startOutput);
    $('#week_end').val(endOutput);
    $('#week_selector').val(startOutput + " to " + endOutput);
    $('#js_week_start').val(rStart);
    $('#js_week_end').val(rEnd);
  },

  openDialog: function(button) {
    var taskType = $(button).attr('rel');
    if(taskType == 'project') {
      $('#dialog-add-proj-task').dialog('option', 'title', 'Add Project Related Task');
      $('#dialog-add-proj-task').dialog('open');
    }
    else if(taskType == 'admin') {
      $('#dialog-add-non-proj-task').dialog('option', 'title', 'Add Non-Project (Admin) Related Task');
      $('#dialog-add-non-proj-task').dialog('open');
    }
  },

  validate: function(value) {
    if(value.length === 0) {
      return 'Issue ID is required.';
    } else if(!/^\s*\d+\s*$/.test(value)) {
      return 'Issue ID should be a number.';
    } else if($('#issue-' + value).length > 0) {
      return 'You have already added this issue.'
    } else {
      return true;
    }
  },

  submit: function(issues, existing, type, id) {
      var i;
      if(issues.length>0) {
        $('#ajax-indicator').show();
        $.ajax({
            type: 'post',
            url: '/week_logs/add_task.js',
            data: { 'id': issues, 'type': type, 'week_start': $('#week_start').val() },
            success: function() {
              $("#"+id).dialog('close');
              Week.repopulateTable(issues, type);
              $('#ajax-indicator').hide();
            },
            error: function(data) {
              $('#ajax-indicator').hide();
              $("#"+id).find('.error').removeClass('hidden');
              var errors = JSON.parse(data.responseText);
              $(errors).each(function(i,val){
                  i = issues.indexOf(val.replace(/\D+/gi,""));
                  while(i>=0) {
                    issues.splice(i, 1);
                    i = issues.indexOf(val.replace(/\D+/gi,""));
                  }
                  $("#"+id).find('.error').append(val+"<br/>");
              });
              if(issues.length>0) {
                Week.repopulateTable(issues, type);
              }
            }
          });
      } else {
        $(".issue-table .result-error").addClass("hidden");
        if(existing.length>0)
          var text = "";
          if(existing.length==1)
            text = "You have already added this issue:"
          else
            text = "You have already added these issues:"
          $("#"+id).find('.error').append(text+" "+existing.join(',')+"<br/>").removeClass('hidden');
        if(issues.length == 0 && existing.length==0)
          $("#"+id).find('.error').append("Please select an issue<br/>").removeClass('hidden');
      }
  },

  resetDialog: function(dialog, type) {
    dialog.find("#search-id").val("");
    dialog.find("#task-id").val("");
    if(type=="project") {
      $('.add-task-proj>option:eq(0)').attr('selected', true);
      $('.project_iter>option:eq(0)').attr('selected', true);
      $('.search-task-proj>option:eq(0)').attr('selected', true);
      dialog.find("#clear-proj").click();
    } else { 
      $('.add-task-non-proj>option:eq(0)').attr('selected', true);
      $('.search-task-non-proj>option:eq(0)').attr('selected', true);
      dialog.find("#clear-non-proj").click();
    }
  },

  refreshTableDates: function() {
    var start = new Date($("#js_week_start").val());
    var end = new Date();
    var inspect = new Date(start);
    var i = 0;
    var flag = false;
    var maxDate = new Date(inspect);
    var days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    maxDate.setDate(maxDate.getDate()+7);
    while(i<7) {
      $('th.' + days[i]).html(days[i].capitalize() + '<br />' + inspect.getDate());
      flag == true ? $('.' + days[i]).hide() : $('.' + days[i]).show();
      if(inspect.toDateString() == end.toDateString() && flag == false)
        flag = true;
      i++;
      inspect.setDate(inspect.getDate()+1);
    }
  },

  repopulateTable: function(taskId, type) {
    if(type)
      loadSpecificTable(taskId, type);
    else
      loadAllTables(taskId);
  },

  refreshTableRowColors: function(table) {
    var rows = table.find('tbody').find('tr.issue').not('.hidden'), i;
    for(i = 0; length = rows.length, i < length; i++) {
      $(rows[i]).removeClass('odd even').addClass(i % 2 != 0 ? 'even' : 'odd');
    }
  },

  refreshTabIndices: function() {
    var rows = $('tr.issue').not('.hidden'), cells, i, j;
    for(i = 0; length = rows.length, i < length; i++) {
      cells = $(rows[i]).find('td.date').not(':hidden').find('input');
      for(j = 0; sublength = cells.length, j < sublength; j++) {
        cells[j].tabIndex = (i * 7) + (j + 1);
      }
    }
    document.getElementById('submit_button').tabIndex = (i * 7) + (j + 1);
  },

  refreshIssueTotal: function(field) {
    var row = $(field).parents('.issue'),
      dateFields = row.find('.date').find('input'),
      totalField = row.find('.total'),
      total = 0, hours;
    dateFields.each(function(i, el) {
      total += parseFloat($(el).attr('data-rvalue'));
    });
    totalField.attr({ 'data-rvalue': total, title: total, value: Week.formatHours(total) });
    Week.refreshTotalHours(field);
  },

  refreshTotalHours: function(field) {
    var projTotal = 0.0, nonProjTotal = 0.0,
      dialogWin = $('#dialog-error-messages'),
      dailyTotals = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      projDailyTotals, nonProjDailyTotals;
    var flag = false;
    projDailyTotals = $('#proj_table').find("input.daily");
    projDailyTotals.each(function(h, e) {
      var total = 0.0,
        hoursDay = $("#proj_table").find("input." + $(e).attr("summary"));
      hoursDay.each(function(i, el) {
        total += Week.parseHours($(el).attr('data-rvalue'));
      });
      $(e).attr({ 'data-rvalue': total, title: total, value: Week.formatHours(total) });
      dailyTotals[h] += total;
      projTotal += total;
    });
    nonProjDailyTotals = $('#non_proj_table').find("input.daily");
    nonProjDailyTotals.each(function(h, e) {
      var total = 0.0,
        hoursDay = $("#non_proj_table").find("input." + $(e).attr("summary"));
      hoursDay.each(function(i, el) {
        total += Week.parseHours($(el).attr('data-rvalue'));
      });
      $(e).attr({ 'data-rvalue': total, title: total, value: Week.formatHours(total) });
      dailyTotals[h] += total;
      nonProjTotal += total;
    });

    $('#total_proj').attr({ 'data-rvalue': projTotal, title: projTotal, value: Week.formatHours(projTotal) });
    $('#total_non_proj').attr({ 'data-rvalue': nonProjTotal, title: nonProjTotal, value: Week.formatHours(nonProjTotal) });
    $('#total_hours').attr({ 'data-rvalue': (projTotal + nonProjTotal), title: (projTotal + nonProjTotal), value: Week.formatHours(projTotal + nonProjTotal) });

    for(var d = 0; d < dailyTotals.length; d++) {
      var day = $("#proj_table thead tr").children(':eq('+(d+3)+')').attr("class").split(' ')[0];
      if(dailyTotals[d] > 24) {
        $("."+day).addClass("day_error");
        flag = true;
      }
      else {
        $("."+day).removeClass("day_error");
      }
    }
    if($(field).hasClass("day_error")) {
      dialogWin.html($('<p />').html('Cannot log more than 24 hours per day'));
      dialogWin.dialog("option", "height", "auto");
      dialogWin.dialog('open');
      formatErrorDialog(dialogWin);
    }
  },

  createErrorDialog: function(data) {
    var dialogWin = $("#dialog-error-messages")
    var project = data["project"], nonProj = data["non_project"]
    dialogWin.html("");
    if(JSON.stringify(project)!="{}" || JSON.stringify(nonProj)!="{}") {
      if(JSON.stringify(project)!="{}") {
        dialogWin.append("<h3>Project</h3>");
        for(var i in project){
          var errorMsg = project[i].split(/\./);
          $.each(errorMsg, function(index, val) {
            if(val != "")
            dialogWin.append("<p>"+i+":"+val+"</p>");
          });
        }
      }

      if(JSON.stringify(nonProj)!="{}") {
        dialogWin.append("<h3>Non-project</h3>");
        for(var v in nonProj) {
          var errorMsg = nonProj[v].split(/\./);
          $.each(errorMsg, function(index, val) {
            if(val != "")
            dialogWin.append("<p>"+v+":"+val+"</p>");
          });
        }
      }
      dialogWin.dialog("open");
      formatErrorDialog(dialogWin);
    } else { return false; } // if no errors, return false
  },

  formatHours: function(hours) {
    var value = parseFloat(parseFloat(hours).toPrecision(12)).toFixed(2);
    if(value == "0.00")
      {return " ";}
    else
      {return value;}
  },

  parseHours: function(hours) {
    // ported from Rails Redmine Core
    hours = hours.toString().trim();
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
  },

  isHours: function(hours) {
    return /^(\d+([.,]\d+)?h?|\d+:\d+|\d+\s*(h|hours)\s*(\d+\s*(m|min)?)?|\d+\s*(m|min)?)$/.test(hours.toString());
  }
}

$(document).ready(function(){
  Week.init();
});
