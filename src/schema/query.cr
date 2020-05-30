require "graphql"
require "../models/*"
require "./context"

@[GraphQL::Object]
class Query
  include GraphQL::ObjectType
  include GraphQL::QueryType

  @[GraphQL::Field]
  def user(context : UserContext) : Models::Member?
    context.user
  end

  @[GraphQL::Field]
  def member(email : String) : Models::Member
    Models::Member.with_email email
  end

  @[GraphQL::Field]
  def members(include_class : Bool = true, include_club : Bool = true, include_inactive : Bool = false) : Array(Models::Member)
    Models::Member.all.select do |member|
      enrollment = member.get_semester(Models::Semester.current.name).try &.enrollment

      (include_class && enrollment == Models::ActiveSemester::Enrollment::CLASS) ||
        (include_club && enrollment == Models::ActiveSemester::Enrollment::CLUB) ||
        (include_inactive && enrollment.nil?)
    end
  end

  @[GraphQL::Field]
  def event(id : Int32) : Models::Event
    Models::Event.with_id id
  end

  @[GraphQL::Field]
  def events : Array(Models::Event)
    Models::Event.for_semester Models::Semester.current.name
  end

  # publicEvents: [PublicEvent!]!

  @[GraphQL::Field]
  def absence_requests : Array(Models::AbsenceRequest)
    Models::AbsenceRequest.for_semester Models::Semester.current.name
  end

  @[GraphQL::Field]
  def gig_request(id : Int32) : Models::GigRequest
    Models::GigRequest.with_id id
  end

  @[GraphQL::Field]
  def gig_requests : Array(Models::GigRequest)
    Models::GigRequest.all
  end

  @[GraphQL::Field]
  def variable(key : String) : Models::Variable
    Models::Variable.with_key key
  end

  @[GraphQL::Field]
  def meeting_minutes(id : Int32) : Models::Minutes
    Models::Minutes.with_id id
  end

  @[GraphQL::Field]
  def all_meeting_minutes : Array(Models::Minutes)
    Models::Minutes.all
  end

  @[GraphQL::Field]
  def current_semester : Models::Semester
    Models::Semester.current
  end

  @[GraphQL::Field]
  def semester(name : String) : Models::Semester
    Models::Semester.with_name name
  end

  @[GraphQL::Field]
  def semesters : Array(Models::Semester)
    Models::Semester.all
  end

  @[GraphQL::Field]
  def uniform(id : Int32) : Models::Uniform
    Models::Uniform.with_id id
  end

  @[GraphQL::Field]
  def uniforms : Array(Models::Uniform)
    Models::Uniform.all
  end

  @[GraphQL::Field]
  def documents : Array(Models::Document)
    Models::Document.all
  end

  @[GraphQL::Field]
  def song(id : Int32) : Models::Song
    Models::Song.with_id id
  end

  @[GraphQL::Field]
  def songs : Array(Models::Song)
    Models::Song.all
  end

  @[GraphQL::Field]
  def song_link(id : Int32) : Models::SongLink
    Models::SongLink.with_id id
  end

  @[GraphQL::Field]
  def public_songs : Array(Models::PublicSong)
    Models::Song.all_public
  end

  @[GraphQL::Field]
  def static : StaticData
    StaticData.new
  end

  @[GraphQL::Field]
  def transactions : Array(Models::ClubTransaction)
    Models::ClubTransaction.for_semester Models::Semester.current.name
  end

  @[GraphQL::Field]
  def fees : Array(Models::Fee)
    Models::Fee.all
  end

  @[GraphQL::Field]
  def officers : Array(Models::MemberRole)
    Models::MemberRole.current_officers
  end

  @[GraphQL::Field]
  def current_permissions : Array(Models::RolePermission)
    Models::RolePermission.all
  end
end

@[GraphQL::Object]
class StaticData
  include GraphQL::ObjectType

  @[GraphQL::Field]
  def media_types : Array(Models::MediaType)
    Models::MediaType.all
  end

  @[GraphQL::Field]
  def permissions : Array(Models::Permission)
    Models::Permission.all
  end

  @[GraphQL::Field]
  def roles : Array(Models::Role)
    Models::Role.all
  end

  @[GraphQL::Field]
  def event_types : Array(Models::EventType)
    Models::EventType.all
  end

  @[GraphQL::Field]
  def sections : Array(String)
    Models::SectionType.all.map &.name
  end

  @[GraphQL::Field]
  def transaction_types : Array(String)
    Models::TransactionType.all.map &.name
  end
end
