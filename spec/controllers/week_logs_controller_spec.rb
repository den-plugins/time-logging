require 'spec_helper'

describe WeekLogsController do
  before(:all) do
    @user = Factory(:test_user)
    @project = @user.projects.select{|x| !x.project_type.to_s.downcase['admin']}
    @non_project = @user.projects.select{|x| !@project.include?(x)}
    @fc = Factory(:fixed_cost)
    #set_allocated_days
    #set_non_billable_days
    #set_billable_days_here
    #@billable_issue
    #@nbillable_issue
  end
  
  before(:each) do
    controller.stub!(:check_if_login_required).and_return(true)
    controller.logged_user = @user
  end
  
  after(:all) do
    @user.destroy
    @fc.destroy
  end

  context "On initial page load" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end

    it "should have project issues" do
      post 'load_tables', :load_type=>'project'
      assigns(:issues)[:project_related].should_not be_nil 
    end

    it "should have non project issues" do
      post 'load_tables', :load_type=>'admin'
      assigns(:issues)[:non_project_related].should_not be_nil
    end

    it "should have filter choices" do
      get 'index'
      assigns(:all_project_names).should_not be_nil
      assigns(:tracker_names).should_not be_nil
      assigns(:project_names).should_not be_nil
      assigns(:iter_proj).should_not be_nil
      assigns(:iter_proj)[0].should be == "All Issues"
      assigns(:non_project_names).should_not be_nil
    end

    it "should display default values in browse add task" do
      get 'index'
      assigns(:proj_issues).should be_nil
      assigns(:non_proj_issues).should be_nil
    end
  end

  describe "Function Add Task" do
    context "Add Project Issue as Billable Resource" do
      it "should add a billable issue on billable days"
      it "should not add a billable issue on non-billable days"
      it "should not add a billable issue on unallocated days"
      it "should not add a billable issue if project budget was consumed"

      it "should add a non-billable issue on billable days"
      it "should add a non-billable issue on non-billable days"
      it "should add a non-billable issue on allocated days"
      it "should not add a non-billable issue on unallocated days"
      
      it "should not add a non-project issue"
      it "should not add if not a member of issue's project"
      it "should not add existing issues"
    end
    
    context "Add Project Issue as Non-Billable Resource" do
      it "should add a non-billable issue on non-billable days"
      it "should add a non-billable issue on allocated days"
      it "should not add a non-billable issue on unallocated days"
      
      it "should not add a billable issue on non-billable days"
      it "should not add a billable issue on allocated days"
      it "should not add a billable issue on unallocated days"
      
      it "should not add a non-project issue"
      it "should not add if not a member of issue's project"
      it "should not add existing issues"
    end

    context "Add Non-Project Issue" do
      it "should not add a non-project issue"
      it "should add from a project he/she is not a member of"
      it "should not add existing issues"
    end
  end
  
  describe "Function Search Task" do
    context "Seach Project Issues"
    context "Search Non-Project Issues"
  end

  describe "Function Filter Issues" do
  end

  describe "Function Iteration Refresh" do
  end

  describe "Save Logs" do
  end
  
end
