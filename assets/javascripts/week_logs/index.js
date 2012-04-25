$(document).ready(function(){
  initializers();
  Week.init();
});

function initializers() {
  if (typeof Week === 'undefined') {
    Week = {};
  }

  Week.start = null;
  Week.end = null;

  Week.updateDateFields = function() {
    var origin = Week.start,
      rStart = new Date(origin.getFullYear(), origin.getMonth(), origin.getDate() + 1),
      rEnd = new Date(origin.getFullYear(), origin.getMonth(), origin.getDate() + 7),
      startOutput = $.datepicker.formatDate('m/d/yy', rStart),
      endOutput = $.datepicker.formatDate('m/d/yy', rEnd);
    $('#week_start').val(startOutput);
    $('#week_end').val(endOutput);
    $('#week_selector').val(startOutput + " to " + endOutput);
    $('#js_week_start').val(rStart);
    $('#js_week_end').val(rEnd);
  };

  Week.init = function() {
    var today = new Date();
    Week.start = new Date(today.getFullYear(), today.getMonth(), today.getDate() - today.getDay());
    Week.end = new Date();
    Week.updateDateFields();
    Week.refreshTableDates();
    Week.refreshTotalHours();
    Week.refreshTabIndices();

    $('#week_selector').datepicker({
      maxDate: today,
      gotoCurrent: true,
      showOn: "button",
      buttonImage: "",
      firstDay: 7,
      onSelect: function(selectDate) {
        var sd = new Date(selectDate);
        if(sd.getDay()==0) sd = new Date(sd-7);
        if(sd < Week.start || sd > Week.end) {
          Week.start = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay());
          Week.end = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay() + 6);
          if(Week.end > today) Week.end = today;
          Week.updateDateFields();
          Week.repopulateTable();
        } else {
          Week.updateDateFields();
        }
      },
      beforeShowDay: function(dates) {
        var cssClass = '';
        if(dates >= Week.start && dates <= Week.end)
          cssClass = 'ui-state-highlight ui-state-active';
        return [true, cssClass];
      },
    });

    function createJsonObject(id) {
      var row = {};
      $(id).find('td.date.changed').find('input').each(function(i, el) {
        el = $(el);
        var issue = el.data('issue'),
          date = el.data('date');
        if(!row.hasOwnProperty(issue)) {
          row[issue] = {};
        }
        row[issue][date] = el.attr('data-rvalue');
      });
      return row;
    };

    $("#submit_button").live("click", function(){
      $('#success_message').text('').addClass('hidden');
      if($(".day_error").length==0) {
          var button = $(this);
          var on_submission_errors = false;
          $('#ajax-indicator').show();
          button.attr('disabled', true);
          $.post("/week_logs/update", {
                  startdate: $("#week_start").val(),
                  project: createJsonObject("#proj_table"),
                  non_project: createJsonObject("#non_proj_table")
          }, function(data) {
                  Week.repopulateTable();
                  on_submission_errors = Week.createErrorDialog(data);
          }).complete(function(data) {
                  if (on_submission_errors == false) {
                    $('#ajax-indicator').hide();
                    $('#success_message').text('Successful update.').removeClass('hidden');
                    $(window).scrollTop(0,0);
                  }
                  button.attr('disabled', false);
          })
      }
      else {
          dialogWin = $('#dialog-error-messages');
          dialogWin.html($('<p />').html('Please check your timesheet'));
          dialogWin.dialog('open');
          formatErrorDialog(dialogWin);
      }
    });
  };

  $(".hide-button").live("click", function(){
    var title = 'Remove Task',
        tbody;
    if($(this).hasClass('proj'))
      title = 'Remove Project Related Tasks';
    else if($(this).hasClass('non_proj'))
      title = 'Remove Non-Project (Admin) Related Tasks';
    
    if($(this).attr("rel")=="project")
      tbody = $("#proj_table tbody");  
    else if($(this).attr("rel")=="admin")
      tbody = $("#non_proj_table tbody");
    
    $(tbody.children()).each(function(index, tr){
      var row = $("#"+tr.id);
      if(row.find('.hide-box').is(':checked'))
        row.addClass("selected");
    });

    $("#dialog-remove-task").dialog('option', 'title', title);
    $("#dialog-remove-task").dialog("open");
  });

  Week.addTask = {
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
                $('#ajax-indicator').hide();
                Week.repopulateTable(issues);
                Week.refreshTableDates();
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
                  Week.repopulateTable(issues);
                  Week.refreshTableDates();
                }
              }
            });
        }
        if(existing.length>0)
          $("#"+id).find('.error').append("You have already added these issues: "+existing.join(',')+"<br/>").removeClass('hidden');
        if(issues.length == 0 && existing.length==0)
          $("#"+id).find('.error').append("Please select an issue<br/>").removeClass('hidden');
    }
  };

  $('.date').find('input').live('change', function(e) {
    // mimic html5 number field behavior
    var hours = Week.parseHours(this.value), min = 0, max = 24, step = 0.5;
    switch(e.which) {
      case 38: // up
        if(hours + step <= max)
          this.value = parseFloat(hours + step);
        else
          this.value = max;
        this.value = parseFloat(this.value);
        this.select();
        break;
      case 40: // down
        if(hours - step >= min)
          this.value = parseFloat(hours - step);
        else
          this.value = min;
        this.value = parseFloat(this.value);
        this.select();
        break;
    }
    var hours = this.value.trim();
    if(!Week.isHours(hours)) {
      this.value = parseFloat(/\d+/.test(this.value) ? this.value.match(/\d+/)[0] : 0);
    }
    $(this).attr({ 'data-rvalue': Week.parseHours(this.value),
                   title: Week.parseHours(this.value) });
    if(/^\d+(\.\d+)?$/.test(hours)) {
      this.value = Week.formatHours(hours);
    }
    $(this).parents('td').addClass('changed');
    Week.refreshIssueTotal(this);
  });

  $('.head-button').live('click', function() {
    Week.addTask.openDialog(this);
  });
  
  Week.resetDialog = function(dialog, type) {
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
  };

  Week.refreshTableDates = function() {
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
  };

  Week.repopulateTable = function(taskId) {
    var href = "/week_logs?", taskRow, arr=[];
    href+="&week_start="+$("#week_start").val();
    $('#ajax-indicator').show();
    $.getScript(href, function() {
      Week.refreshTotalHours();
      Week.refreshTableDates();
      Week.refreshTabIndices();
      $('#ajax-indicator').hide();
      if(taskId && taskId.length > 0) {
        arr = getUniqueValues(taskId);
        $('#success_message').text('Successfully added #' + arr + '.').removeClass('hidden');
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
  };

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

  Week.refreshIssueTotal = function(field) {
    var row = $(field).parents('.issue'),
      dateFields = row.find('.date').find('input'),
      totalField = row.find('.total'),
      total = 0, hours;
    dateFields.each(function(i, el) {
      total += parseFloat($(el).attr('data-rvalue'));
    });
    totalField.attr({ 'data-rvalue': total, title: total, value: Week.formatHours(total) });
    Week.refreshTotalHours(field);
  };

  Week.refreshTotalHours = function(field) {
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

    if(flag) {
      dialogWin.html($('<p />').html('Cannot log more than 24 hours per day'));
      dialogWin.dialog('open');
      formatErrorDialog(dialogWin);
    }
  };
  Week.createErrorDialog = function(data) {
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
  };

  Week.formatHours = function(hours) {
    return parseFloat(parseFloat(hours).toPrecision(12)).toFixed(2);
  };

  Week.parseHours = function(hours) {
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
  };

  Week.isHours = function(hours) {
    return /^(\d+([.,]\d+)?h?|\d+:\d+|\d+\s*(h|hours)\s*(\d+\s*(m|min)?)?|\d+\s*(m|min)?)$/.test(hours.toString());
  };
  
  function formatErrorDialog(dialog) {
    dialog.parent().find(".ui-dialog-titlebar").css({'background' : 'url(/plugin_assets/time_logging/stylesheets/images/ui-bg_highlight-soft_33_e3675c_1x100.png) 50% 50% repeat-x', 'border' : '1px solid #810405'});
    dialog.parent().find(".ui-dialog-buttonset button").css({'background' : 'url(/plugin_assets/time_logging/stylesheets/images/ui-bg_highlight-soft_60_e3675c_1x100.png) 50% 50% repeat-x', 'border' : '1px solid #810405'});
  };

  $("#dialog-remove-task").dialog({
    autoOpen: false,
    width: 300,
    resizable: false,
    modal: true,
    buttons: {
      "Yes": function() {
      var dialogWin = $("#dialog-error-messages");
      var bValid = true;
      var flag = true;
      var arrDel = [], tr;
      var row = $("tr.selected"),
        table;
      
      $(row).each(function(index, val){
        tr = $("#"+val.id);
        table = tr.parents('table');
        flag = true;
        $.map(tr.find("td input"), function(n,i) {
          if($(n).val()>0) {
            flag = false;
            row.removeClass("selected");
          }
        });
        if(flag) {
          arrDel.push(val.id.replace(/\D+/g, ''));
          tr.remove(); 
        }
      });

      if(arrDel.length > 0) {
        Week.refreshTableRowColors(table);
        Week.refreshTotalHours();
        Week.refreshTabIndices();
        $.post('/week_logs/remove_task.js', {id: arrDel});
      }
      if(row.length > 0 && arrDel.length < row.length) {
        dialogWin.html($('<p />').html('Cannot remove a task with existing logs'));
        dialogWin.dialog('open');
        formatErrorDialog(dialogWin);
      }
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

  $("#dialog-add-proj-task, #dialog-add-non-proj-task").dialog({
    autoOpen: false,
    width: 650,
    zIndex: 50,
    modal: true,
    resizable: false,
    buttons: {
      "Add": function() {
        var tbody = $(this).find("#issue-board tbody");
        var issues = [], manual_issue = $(this).find("#task-id").val();
        var validOrError, existing = []
        var id = $(this).attr('id');
        var type;

        $(this).find('.error').html("").addClass('hidden');
        if(id == "dialog-add-proj-task")
          type = "project";
        else
          type = "admin";

        tbody.children().each(function(){
          if($(this).find('.add-issue').is(':checked')) {
            validOrError = Week.addTask.validate($(this).attr('class'));
            if(validOrError === true) 
              issues.push($(this).attr('class'));
            else if(validOrError == "You have already added this issue.") {
              existing.push($(this).attr('class'));
            }
          }
        });
        
        validOrError = Week.addTask.validate(manual_issue);
        if(validOrError === true)
          issues.push(manual_issue)
        else if(validOrError == "You have already added this issue.") {
          existing.push(manual_issue);
        }
        else if(validOrError == "Issue ID should be a number.")
          $(this).find('.error').removeClass('hidden').append("Issue ID should be a number.<br/>");
        existing = getUniqueValues(existing);
        Week.addTask.submit(issues, existing, type, id);
      },
      "Cancel": function() {
        $(this).dialog("close");
      }
    },
    close: function(ev, ui) {
      if($(this).attr("id") == "dialog-add-proj-task")
        $("#clear-proj").click();
      else
        $("#clear-non-proj").click();
    }
  });

  $(".add-task-proj").live("change", function(){
    var parent = $("#dialog-add-proj-task");
    parent.find(".error").html("").addClass("hidden");
    if($(this).val()!="All Projects") {
        $('#ajax-indicator').show();
        $.post("/week_logs/iter_refresh",
              {
                project: $(this).val()
              })
        .complete(function() { $('#ajax-indicator').hide();}) 
    }
  });
  
  $(".add-task-non-proj").live("change", function(){
    var parent = $("#dialog-add-non-proj-task");
    parent.find(".error").html("").addClass("hidden");
  });

  $(".project_iter").live("change", function(){
     var parent = $("#dialog-add-proj-task");
     parent.find(".error").html("").addClass("hidden");
  });
  
  $("#add-task-proj-search, #add-task-non-proj-search").live("click", function(){
    var type, project, iter, parent, error, search, task, existing = [];

    if($(this).attr('id') == "add-task-proj-search") {
      parent = $("#dialog-add-proj-task"); 
      type = "project";
      project = $(".add-task-proj").val();
      iter = $(".project_iter option:selected").text();
      $("#proj_table .issue").each(function(){
        existing.push($(this).attr("id").replace(/issue\-/, ""))
      });
    } else {
      parent = $("#dialog-add-non-proj-task"); 
      type = "admin";
      project = $(".add-task-non-proj").val();
      iter = "All Issues";
      $("#non_proj_table .issue").each(function(){
        existing.push($(this).attr("id").replace(/issue\-/, ""))
      });
    }
    error = parent.find(".error");
    error.html("").addClass("hidden");
    search = parent.find("#search-id").val();
    task = parent.find("#task-id").val();
    $('#ajax-indicator').show();
    $.post("/week_logs/task_search",
          {
            type: type,
            project: project,
            iter: iter,
            search: search,
            exst: existing,
            task: task
          }) 
    .complete(function() { $('#ajax-indicator').hide();}) 
  });
  
  $("#clear-proj, #clear-non-proj").live("click", function(){
    var parent; 
    if($(this).attr("id") == "clear-proj") {
      parent = $("#dialog-add-proj-task");
      parent.find("#add-task-proj-issue-board").html("");
      parent.find(".add-task-proj>option:eq(0)").attr('selected', true);
      parent.find(".project_iter>option:eq(0)").attr('selected', true);
      reset_iterations_field();
    } else {
      parent = $("#dialog-add-non-proj-task");
      parent.find("#add-task-non-proj-issue-board").html("");
      parent.find(".add-task-non-proj>option:eq(0)").attr('selected', true);
    }
    parent.find("#task-id").val("");
    parent.find("#search-id").val("");
    parent.find(".error").html("").addClass('hidden');
  });

  $("#dialog-error-messages").dialog({
    autoOpen: false,
    width: 'auto',
    modal: true,
    resizable: false,
    title: 'Error Message',
    buttons: {
      "Ok": function() {
        $(this).dialog("close");
      }
    },
  });

  $("a.proj").live("click", function(){
    var addtl_params="";
    var href = this.href;
    if($("#non_proj").val()!="")
      addtl_params += "&non_proj="+$("#non_proj").val()+""; 
    if($("#non_proj_dir").val()!="")
      addtl_params += "&non_proj_dir="+$("#non_proj_dir").val()+"";
    href+= addtl_params;
    addtl_params += "&f_proj_name="+$("select.project").val()+"&f_tracker="+$("select.tracker").val()+"";
    event.preventDefault();
    $.getScript(href);
  });
  
  $("a.non_proj").live("click", function(){
    var addtl_params="";
    var href = this.href;
    if($("#proj").val()!="")
      addtl_params += "&proj="+$("#proj").val()+""; 
    if($("#proj_dir").val()!="")
      addtl_params += "&proj_dir="+$("#proj_dir").val()+"";
    addtl_params += "&f_proj_name="+$("select.project").val()+"&f_tracker="+$("select.tracker").val()+"";
    href+= addtl_params;
    event.preventDefault();
    $.getScript(href);
  });
  
  $("a.project, a.task_activity").live({
    mouseenter:
      function(e) {
        var tooltip = $(".tooltip");
        tooltip.html("");
        if($(this).hasClass("project"))
          tooltip.append("<p>Sort by Project Name</p>");
        else
          tooltip.append("<p>Sort by Task/Activity</p>");
        tooltip.css({
          left:e.pageX,
          top:e.pageY
        });
        tooltip.show();
      },
    mouseleave:
      function() {
        $(".tooltip").hide();
      }
  });

  $("a.apply_button").live("click", function(){
    $('#success_message').text('').addClass('hidden');
    $('#ajax-indicator').show();
    var href = "/week_logs/?";
    href+="proj="+$("#proj").val();
    href+="&proj_dir="+$("#proj_dir").val();
    href+="&non_proj="+$("#non_proj").val();
    href+="&non_proj_dir="+$("#non_proj_dir").val();
    href+="&f_proj_name="+$("select.project").val();
    href+="&f_tracker="+$("select.tracker").val();
    $.getScript(href)
    .success(function() { $('#ajax-indicator').hide();}) 
  });

  $("#add_task_project, #add_task_non_project, #project_iter").live('change', function(){
      $("#add-task-proj-issue-board, #add-task-non-proj-issue-board").empty();
      reset_iterations_field();
  });
  
  reset_iterations_field();

}


function getUniqueValues(array) {
  var newArr = [];
  $(array).each(function(index,val){
    if(newArr.indexOf(val)==-1)
      newArr.push(val);
  });
  return newArr;
}

function reset_iterations_field() {
  if ($("#add_task_project").val() == "All Projects"){
    $("#project_iter").html("<option>All Issues</option>");
  }
}
