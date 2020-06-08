require "ecr"
require "log"
require "email"

require "./models/member/**"

module Emails
  DEFAULT_NAME    = "Glee Club Officers"
  DEFAULT_ADDRESS = "gleeclub_officers@lists.gatech.edu"

  class ResetPassword
    def initialize(@email : String, @new_token : String)
    end

    ECR.def_to_s "templates/forgot_password.html.ecr"

    def self.send(email, new_token)
      EMail.send "localhost", log: (Log.for "*", :error) do
        from DEFAULT_ADDRESS
        to email
        subject "Reset Your GlubHub Password"
        message (new email, new_token).to_s
      end
    end
  end
end
