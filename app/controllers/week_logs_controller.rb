class WeekLogsController < ApplicationController

  def index
    @user = User.current
    issue_conditions = []
    issue_conditions << "assigned_to_id = #{@user.id}"
    @issues = Issue.find(:all, :conditions => issue_conditions)
  end
  
  def create
  end
  
  def show
  end
  
  def edit
  end
  
  def update
  end
  
  def destroy
  end

end
