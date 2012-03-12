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

  Week.getWeek = function(select_date) {
    var week = new Array();
    for (i = 0; i < 7; i++) {
      var tempDate = new Date(select_date);
      tempDate.setDate(tempDate.getDate() - i);
      week.push(tempDate.getTime());
    }
    return week;
  };
  
  Week.init = function() {
    Week.collection = new Array();
    var current_date = new Date();
    $('#week_selector').datepicker({
      maxDate: new Date(currentYear, currentMonth, currentDate),
      showOn: "button",
      buttonImage: "",
      beforeShowDay: function(date) {
        if ($.inArray(date.getTime(), Week.collection) >= 0) 
          return [true, "highlighted-week", "Week Range"];
        else
          return [true, "", ""];
      },
      onSelect: function(select_date) {
        Week.collection = Week.getWeek(new Date(current_date.getFullYear(),
                                                current_date.getMonth(),
                                                current_date.getDate()));
        var date = new Date(select_date);
        Week.collection = Week.getWeek(date);
        var start = new Date(date.getFullYear(), date.getMonth(), date.getDate()-6);
        var end = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        var start_output = start.getDate()+"/"+(start.getMonth()+1)+"/"+start.getFullYear();
        var end_output = end.getDate()+"/"+(end.getMonth()+1)+"/"+end.getFullYear();
        $('#reports_week_start').val(start_output);
        $('#reports_week_end').val(end_output);
        $('#week_selector').val(start_output+" to "+end_output);
      },
    });
  };
}
