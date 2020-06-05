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

  def able_to?(permission, event_type = nil)
    user!.permissions.any? do |p|
      p.name == permission && (!event_type || p.event_type == event_type)
    end
  end

  def able_to!(permission, event_type = nil)
    raise "Permission #{permission} required" unless able_to? permission, event_type
  end
end
