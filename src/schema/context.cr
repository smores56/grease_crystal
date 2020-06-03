require "graphql"
require "../models/member"

class UserContext < GraphQL::Context
  @user : Models::Member?

  def initialize(token : String?)
    @user = token ? (Models::Member.load_from_token token) : nil
  end

  def user
    @user
  end

  def user!
    @user || raise "User must be logged in"
  end

  def logged_in!
    user!
  end

  def able_to!(permission, event_type = nil)
    permission = Models::MemberPermission.new permission, event_type

    raise "Permission #{permission} required" unless user!.permissions.includes? permission
  end
end
