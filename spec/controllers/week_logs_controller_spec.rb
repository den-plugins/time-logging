require 'spec_helper'

describe WeekLogsController do
  before(:each) do
    controller.stub!(:check_if_login_required).and_return(true)
    
  end

  context "GET Index" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
end
