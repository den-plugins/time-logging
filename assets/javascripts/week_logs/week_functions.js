function loadAllTables(taskId) {
  $("#submit_button").attr("disabled", true);
  $(".tooltip").hide();
  $(".apply_button").hide();
  $("#proj_related").html("").css({background:"url(images/loading.gif) no-repeat center", height:"100px", border:"1px solid #E4E4E4"});
  $("#non_proj_related").html("").css({background:"url(images/loading.gif) no-repeat center", height:"100px", border:"1px solid #E4E4E4"});
  
  $.ajax({
      type: 'post',
      url: '/week_logs/load_tables',
      data: {'load_type': "project", "f_proj_name":$("select.project").val(), "f_tracker":$("select.tracker").val(), "week_start":$("#week_start").val()},
      error: function(data) {
        console.log(data);
      },
      success: function() {
        loadAllTablesPostProcess(taskId);
        $.ajax({
            type: 'post',
            url: '/week_logs/load_tables',
            data: {'load_type': "admin", "f_proj_name":$("select.project").val(), "f_tracker":$("select.tracker").val(), "week_start":$("#week_start").val()},
            error: function(data) {
              console.log(data);
            },
            success: function() {
              loadAllTablesPostProcess(taskId);
              $("#submit_button").attr("disabled", false);
              $(".apply_button").show();
            }
        });
      }
  });
};

function loadSpecificTable(taskId, type, dir_name) {
    var proj, dir, proj_val, dir_value, datum = {};
    $("#submit_button").attr("disabled", true);
    $(".tooltip").hide();
    $(".apply_button").hide();
    if(type == "project") {
      proj = "proj";
      dir = "proj_dir";
      if(dir_name)
        proj_value = dir_name;
      else
        proj_value = $("#proj").val();
      dir_value = $("#proj_dir").val();
      $("#proj_related").html("").css({background:"url(images/loading.gif) no-repeat center", height:"100px", border:"1px solid #E4E4E4"});
    }
    else if(type == "admin") {
      $("#non_proj_related").html("").css({background:"url(images/loading.gif) no-repeat center", height:"100px", border:"1px solid #E4E4E4"});
      proj = "non_proj";
      dir = "non_proj_dir";
      if(dir_name)
        proj_value = dir_name;
      else
        proj_value = $("#non_proj").val();
      dir_value = $("#non_proj_dir").val();
    }
    datum = {'load_type':type, "f_proj_name":$("select.project").val(), "f_tracker":$("select.tracker").val(), "week_start":$("#week_start").val()};
    datum[proj] = proj_value;
    datum[dir] = dir_value;
    $.ajax({
        type: 'post',
        url: '/week_logs/load_tables',
        data: datum,
        error: function(data) {
          console.log(data);
        },
        success: function() {
          loadAllTablesPostProcess(taskId);
          $("#submit_button").attr("disabled", false);
          $(".apply_button").show();
        }
    });
};

function createJsonObject(id) {
  var row = {};
  $(id).find('td.date.changed').find('input').each(function(i, el) {
    if(!$(this).parent().hasClass("day_error"))
    {
      el = $(el);
      var issue = el.data('issue'),
        date = el.data('date');
      if(!row.hasOwnProperty(issue)) {
        row[issue] = {};
      }
      row[issue][date] = el.attr('data-rvalue');
    }
  });
  return row;
};

function loadAllTablesPostProcess(taskId) {
  Week.refreshTotalHours();
  Week.refreshTabIndices();
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
};

function formatErrorDialog(dialog) {
  dialog.parent().find(".ui-dialog-titlebar").css({'background' : 'url(/plugin_assets/time_logging/stylesheets/images/ui-bg_highlight-soft_33_e3675c_1x100.png) 50% 50% repeat-x', 'border' : '1px solid #810405'});
  dialog.parent().find(".ui-dialog-buttonset button").css({'background' : 'url(/plugin_assets/time_logging/stylesheets/images/ui-bg_highlight-soft_60_e3675c_1x100.png) 50% 50% repeat-x', 'border' : '1px solid #810405'});
};

function getUniqueValues(array) {
  var newArr = [];
  $(array).each(function(index,val){
    if(newArr.indexOf(val)==-1)
      newArr.push(val);
  });
  return newArr;
};

function resetIterationsField() {
  if ($("#add_task_project").val() == "All Projects"){
    $("#project_iter").html("<option>All Issues</option>");
  }
};

$(document).ready(function(){
  resetIterationsField();
});
