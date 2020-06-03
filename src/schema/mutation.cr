require "graphql"
require "./context"
require "../models/input"
require "../permissions"

@[GraphQL::Object]
class Mutation
  include GraphQL::ObjectType
  include GraphQL::MutationType

  @[GraphQL::Field(description: "Gets a login token on successful login")]
  def login(form : Input::LoginInfo) : String
    raise "The given email or password is invalid" unless Models::Member.valid_login? form
    Models::Session.get_or_generate_token form.email
  end

  @[GraphQL::Field(description: "Logs the member out")]
  def logout(context : UserContext) : Bool
    Models::Session.remove_for context.user!.email
    true
  end

  @[GraphQL::Field]
  def forgot_password(email : String) : Bool
    Models::Session.generate_for_forgotten_password email
    true
  end

  @[GraphQL::Field]
  def reset_password(token : String, form : Input::PasswordReset) : Bool
    Models::Session.reset_password token, form.pass_hash
    true
  end

  @[GraphQL::Field]
  def register_member(form : Input::NewMember) : Models::Member
    Models::Member.register form
    Models::Member.with_email form.email
  end

  @[GraphQL::Field]
  def register_for_semester(form : Input::RegisterForSemesterForm, context : UserContext) : Models::Member
    Models::Member.register_for_current_semester context.user!, form
    Models::Member.with_email context.user!.email
  end

  @[GraphQL::Field]
  def update_profile(form : Input::NewMember, context : UserContext) : Models::Member
    Models::Member.update context.user!, form, as_self: true
    Models::Member.with_email form.email
  end

  @[GraphQL::Field]
  def update_member(member : String, form : Input::NewMember, context : UserContext) : Models::Member
    context.able_to! Permissions::EDIT_USER
    Models::Member.update (Models::Member.with_email member), form, as_self: false
    Models::Member.with_email form.email
  end

  @[GraphQL::Field(description: "Gets a login token for the given member")]
  def login_as(member : String, context : UserContext) : String
    context.able_to! Permissions::SWITCH_USER
    Models::Session.get_or_generate_token member
  end

  @[GraphQL::Field(description: "Deletes a member and returns their email")]
  def delete_member(member : String, context : UserContext) : String
    context.able_to! Permissions::DELETE_USER
    Models::Member.delete member
    member
  end

  @[GraphQL::Field]
  def create_event(form : Input::NewEvent) : Models::Event
    new_id = Models::Event.create form
    Models::Event.with_id new_id
  end

  @[GraphQL::Field]
  def update_event(id : Int32, form : Input::NewEvent) : Models::Event
    Models::Event.update id, form
    Models::Event.with_id id
  end

  @[GraphQL::Field(description: "Deletes an event and returns its id")]
  def delete_event(id : Int32) : Int32
    Models::Event.delete id
    id
  end

  @[GraphQL::Field]
  def update_attendance(event_id : Int32, member : String, form : Input::AttendanceForm) : Models::Attendance
    Models::Attendance.update event_id, member, form
    Models::Attendance.for_member_at_event! member, event_id
  end

  @[GraphQL::Field]
  def rsvp_for_event(id : Int32, attending : Bool, context : UserContext) : Models::Attendance
    Models::Attendance.rsvp_for_event id, context.user!, attending
    Models::Attendance.for_member_at_event! context.user!.email, id
  end

  @[GraphQL::Field]
  def confirm_for_event(id : Int32, context : UserContext) : Models::Attendance
    Models::Attendance.confirm_for_event id, context.user!
    Models::Attendance.for_member_at_event! context.user!.email, id
  end

  @[GraphQL::Field]
  def update_carpools(event_id : Int32, carpools : Array(Input::UpdatedCarpool), context : UserContext) : Array(Models::Carpool)
    Models::Carpool.update event_id, carpools
    Models::Carpool.for_event event_id
  end

  @[GraphQL::Field]
  def approve_absence_request(event_id : Int32, member : String) : Models::AbsenceRequest
    Models::AbsenceRequest.set_state event_id, member, Models::AbsenceRequest::State::APPROVED
    Models::AbsenceRequest.for_member_at_event! member, event_id
  end

  @[GraphQL::Field]
  def deny_absence_request(event_id : Int32, member : String) : Models::AbsenceRequest
    Models::AbsenceRequest.set_state event_id, member, Models::AbsenceRequest::State::DENIED
    Models::AbsenceRequest.for_member_at_event! member, event_id
  end

  @[GraphQL::Field]
  def submit_absence_request(event_id : Int32, reason : String, context : UserContext) : Models::AbsenceRequest
    Models::AbsenceRequest.submit event_id, context.user!.email, reason
    Models::AbsenceRequest.for_member_at_event! event_id, context.user!.email
  end

  @[GraphQL::Field]
  def submit_gig_request(form : Input::NewGigRequest, context : UserContext) : Models::GigRequest
    new_id = Models::GigRequest.submit form
    Models::GigRequest.with_id new_id
  end

  @[GraphQL::Field]
  def dismiss_gig_request(id : Int32, context : UserContext) : Models::GigRequest
    Models::GigRequest.set_status id, Models::GigRequest::Status::DISMISSED
    Models::GigRequest.with_id id
  end

  @[GraphQL::Field]
  def reopen_gig_request(id : Int32, context : UserContext) : Models::GigRequest
    Models::GigRequest.set_status id, Models::GigRequest::Status::PENDING
    Models::GigRequest.with_id id
  end

  @[GraphQL::Field]
  def create_event_from_gig_request(request_id : Int32, form : Input::NewEvent, context : UserContext) : Models::Event
    request = Models::GigRequest.with_id request_id
    new_id = Models::Event.create form, request
    Models::Event.with_id new_id
  end

  @[GraphQL::Field]
  def set_variable(key : String, value : String, context : UserContext) : Models::Variable
    Models::Variable.set key, value
    Models::Variable.with_key key
  end

  @[GraphQL::Field]
  def unset_variable(key : String, context : UserContext) : Models::Variable
    var = Models::Variable.with_key key
    Models::Variable.unset key
    var
  end

  @[GraphQL::Field]
  def create_document(name : String, url : String, context : UserContext) : Models::Document
    Models::Document.create name, url
    Models::Document.with_name name
  end

  @[GraphQL::Field]
  def update_document(name : String, url : String, context : UserContext) : Models::Document
    Models::Document.update name, url
    Models::Document.with_name name
  end

  @[GraphQL::Field]
  def delete_document(name : String, context : UserContext) : Models::Document
    document = Models::Document.with_name name
    Models::Document.delete name
    document
  end

  @[GraphQL::Field]
  def create_semester(form : Input::NewSemester) : Models::Semester
    Models::Semester.create form
    Models::Semester.with_name! form.name
  end

  @[GraphQL::Field]
  def update_semester(name : String, form : Input::NewSemester) : Models::Semester
    Models::Semester.update name, form
    Models::Semester.with_name! form.name
  end

  @[GraphQL::Field]
  def set_current_semester(name : String) : Models::Semester
    Models::Semester.set_current name
    Models::Semester.with_name! name
  end

  @[GraphQL::Field]
  def create_meeting_minutes(name : String) : Models::Minutes
    new_id = Models::Minutes.create name
    Models::Minutes.with_id! new_id
  end

  @[GraphQL::Field]
  def update_meeting_minutes(id : Int32, form : Input::UpdatedMeetingMinutes) : Models::Minutes
    minutes = Models::Minutes.with_id! id
    minutes.update form
    minutes
  end

  @[GraphQL::Field]
  def email_meeting_minutes(id : Int32) : Models::Minutes
    minutes = Models::Minutes.with_id! id
    minutes.email
    minutes
  end

  @[GraphQL::Field]
  def delete_meeting_minutes(id : Int32) : Models::Minutes
    minutes = Models::Minutes.with_id! id
    minutes.delete
    minutes
  end

  @[GraphQL::Field]
  def create_uniform(form : Input::NewUniform) : Models::Uniform
    new_id = Models::Uniform.create form
    Models::Uniform.with_id! new_id
  end

  @[GraphQL::Field]
  def update_uniform(id : Int32, form : Input::NewUniform) : Models::Uniform
    uniform = Models::Uniform.with_id! id
    uniform.update form
    uniform
  end

  @[GraphQL::Field]
  def delete_uniform(id : Int32) : Models::Uniform
    uniform = Models::Uniform.with_id! id
    uniform.delete
    uniform
  end

  @[GraphQL::Field]
  def create_song(form : Input::NewSong) : Models::Song
    new_id = Models::Song.create form
    Models::Song.with_id! new_id
  end

  @[GraphQL::Field]
  def update_song(id : Int32, form : Input::SongUpdate) : Models::Song
    song = Models::Song.with_id! id
    song.update form
    song
  end

  @[GraphQL::Field(description: "Deletes a song and returns the id")]
  def delete_song(id : Int32) : Int32
    song = Models::Song.with_id! id
    song.delete
    id
  end

  # createSongLink(songId: Int!, form: NewSongLink!): SongLink!
  # updateSongLink(id: Int!, form: SongLinkUpdate!): SongLink!
  # deleteSongLink(id: Int!): SongLink!

  @[GraphQL::Field]
  def add_permission_to_role(position : String, permission : String, event_type : String?) : Bool
    Models::RolePermission.add position, permission, event_type
    true
  end

  @[GraphQL::Field]
  def remove_permission_from_role(position : String, permission : String, event_type : String?) : Bool
    Models::RolePermission.remove position, permission, event_type
    true
  end

  @[GraphQL::Field]
  def add_officership(position : String, member : String) : Models::MemberRole
    member_role = Models::MemberRole.new member, position
    member_role.add
    member_role
  end

  @[GraphQL::Field]
  def remove_officership(position : String, member : String) : Models::MemberRole
    member_role = Models::MemberRole.new member, position
    member_role.remove
    member_role
  end

  @[GraphQL::Field]
  def update_fee_amount(name : String, amount : Int32) : Models::Fee
    fee = Models::Fee.with_name! name
    fee.set_amount amount
    fee
  end

  # chargeDues: [Transaction!]!
  # chargeLateDues: [Transaction!]!

  @[GraphQL::Field]
  def add_batch_of_transactions(batch : Input::TransactionBatch) : Array(Models::ClubTransaction)
    Models::ClubTransaction.add_batch batch
    Models::ClubTransaction.for_semester Models::Semester.current.name
  end

  @[GraphQL::Field]
  def resolve_transaction(id : Int32, resolved : Bool) : Models::ClubTransaction
    transaction = Models::ClubTransaction.with_id! id
    transaction.resolve resolved
    transaction
  end

  # sendEmail(since: NaiveDateTime!): Boolean!
end
