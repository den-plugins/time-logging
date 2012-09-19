//////// WEEK EVENTS ////////
$("#submit_button").live("click", function(){
  $('#success_message').text('').addClass('hidden');
  var button = $(this), 
      on_submission_errors = false,
      dialogWin = $("#dialog-error-messages");
  if($("td.date.changed").length > 0) {
    $(".apply_button").hide();
    $('#ajax-indicator').show();
    button.attr('disabled', true);
    $.post("/week_logs/update", {
            startdate: $("#week_start").val(),
            project: createJsonObject("#proj_table"),
            non_project: createJsonObject("#non_proj_table")
    }, function(data) {
            $('#ajax-indicator').hide();
            Week.repopulateTable();
            on_submission_errors = Week.createErrorDialog(data);
    }).complete(function(data) {
            if (on_submission_errors == false) {
              $('#success_message').text('Successful update.').removeClass('hidden');
              $(window).scrollTop(0,0);
            }
    });
  } else {
      dialogWin.html($('<p />').html('Please log your time first.'));
      dialogWin.dialog('option', 'height', 'auto')
      dialogWin.dialog('open');
  }
});

$('#week_selector').datepicker({
  maxDate: Week._today,
  gotoCurrent: true,
  showOn: "button",
  buttonImage: "",
  firstDay: 7,
  onSelect: function(selectDate) {
    var sd = new Date(selectDate);
    if(sd.getDay()==0) sd = new Date(sd-7);
    if(sd < Week._start || sd > Week._end) {
      Week._start = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay());
      Week._end = new Date(sd.getFullYear(), sd.getMonth(), sd.getDate() - sd.getDay() + 6);
      if(Week._end > Week._today) Week._end = Week._today;
      Week.updateDateFields();
      Week.repopulateTable();
    } else {
      Week.updateDateFields();
    }
  },
  beforeShowDay: function(dates) {
    var cssClass = '';
    if(dates >= Week._start && dates <= Week._end)
      cssClass = 'ui-state-highlight ui-state-active';
    return [true, cssClass];
  },
});

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
/////////////////////////////////


//////// ADD TASK EVENTS ////////
$('.head-button').live('click', function() {
  Week.openDialog(this);
});

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
      $('#ajax-indicator').show();
      $.post('/week_logs/remove_task.js', {id: arrDel})
      .success(function(){
          $('#ajax-indicator').hide();
          $('#success_message').text('Successfully deleted issues.').removeClass('hidden');
          $(window).scrollTop(0,0);
      });
    }
    if(row.length > 0 && arrDel.length < row.length) {
      dialogWin.html($('<p />').html('Cannot remove a task with existing logs'));
      dialogWin.dialog('option', 'height', 'auto')
      dialogWin.dialog('open');
      formatErrorDialog(dialogWin);
    }
    if (bValid) {
      //If valid execute script and close the dialog.
      if($(this).dialog('option', 'title') == "Remove Project Related Tasks") {
       $("a.sd-proj").removeClass("des-all").addClass("sel-all");
      } else {
       $("a.sd-non-proj").removeClass("des-all").addClass("sel-all");
      }
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
          validOrError = Week.validate($(this).attr('class'));
          if(validOrError === true) 
            issues.push($(this).attr('class'));
          else if(validOrError == "You have already added this issue.") {
            existing.push($(this).attr('class'));
          }
        }
      });
      
      validOrError = Week.validate(manual_issue);
      if(validOrError == true && $.inArray(manual_issue, issues)==-1)
        issues.push(manual_issue);
      else if(validOrError == "You have already added this issue.") 
        existing.push(manual_issue);
      else if(validOrError == "Issue ID should be a number.")
        $(this).find('.error').removeClass('hidden').append("Issue ID should be a number.<br/>");
      existing = getUniqueValues(existing);
      Week.submit(issues, existing, type, id);
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

$("#task-id").filter_input({regex:'[0-9]', live:true});

$("#add-task-proj-search, #add-task-non-proj-search").live("click", function(){
  var type, project, iter, parent, error, search, task;

  if($(this).attr('id') == "add-task-proj-search") {
    parent = $("#dialog-add-proj-task"); 
    type = "project";
    project = $(".add-task-proj").val();
    iter = $(".project_iter option:selected").text();
  } else {
    parent = $("#dialog-add-non-proj-task"); 
    type = "admin";
    project = $(".add-task-non-proj").val();
    iter = "All Issues";
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
    resetIterationsField();
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
  height: 300,
  modal: true,
  resizable: false,
  title: 'Error Message',
  buttons: {
    "Ok": function() {
      $(this).dialog("close");
      $(this).dialog("option", "height", 300);
    }
  },
});

$("a.proj").live("click", function(){
  event.preventDefault();
  loadSpecificTable(null, "project", $(this).removeClass("proj").removeClass("asc").removeClass("desc").attr("class"));
});

$("a.non_proj").live("click", function(){
  event.preventDefault();
  loadSpecificTable(null, "admin", $(this).removeClass("non_proj").removeClass("asc").removeClass("desc").attr("class"));
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

$(".sel-all").live({
  mouseenter:
    function(e) {
      var tooltip = $(".tooltip");
      tooltip.html("");
      tooltip.append("<p>Select All</p>");
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

$(".des-all").live({
  mouseenter:
    function(e) {
      var tooltip = $(".tooltip");
      tooltip.html("");
      tooltip.append("<p>Deselect All</p>");
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
  loadAllTables();
});

$("#add_task_project, #add_task_non_project, #project_iter").live('change', function(){
    $("#add-task-proj-issue-board, #add-task-non-proj-issue-board").empty();
    resetIterationsField();
});

$(".sel-all").live("click", function(){
  $(this).removeClass("sel-all").addClass("des-all");
  $(".tooltip").hide();
  if($(this).hasClass("sd-proj")) {
    $("tr.project").each(function(id, val){$("#"+val.id).find(".hide-box").attr("checked", true)})  
  } else {
    $("tr.admin").each(function(id, val){$("#"+val.id).find(".hide-box").attr("checked", true)})  
  }
});

$(".des-all").live("click", function(){
  $(this).removeClass("des-all").addClass("sel-all");
  $(".tooltip").hide();
  if($(this).hasClass("sd-proj")) {
    $("tr.project").each(function(id, val){$("#"+val.id).find(".hide-box").attr("checked", false)})  
  } else {
    $("tr.admin").each(function(id, val){$("#"+val.id).find(".hide-box").attr("checked", false)})  
  }
});

$(document).ready(function(){
  loadAllTables();
});
/////////////////////////////////
