class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include SetCurrentUser
end
