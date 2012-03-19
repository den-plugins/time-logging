module ExtendAccountController

  def self.included(base)
    base.class_eval do
      before_filter :clear_session, :only => [:logout]
      
      def clear_session
        reset_session
      end
    end
  end
end
AccountController.send(:include,ExtendAccountController)
