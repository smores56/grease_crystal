require "dotenv"
require "graphql"
require "mysql"

Dotenv.load
TRANSACTION = (DB.connect ENV["DATABASE_URL"]).begin_transaction
CONN        = TRANSACTION.connection

module Models
  @[GraphQL::Object]
  class Semester
    include GraphQL::ObjectType

    class_getter table_name = "semester"
    class_getter current : Semester {
      semester = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE current = true", as: Semester
      semester || raise "No current semester set"
    }

    DB.mapping({
      name:            String,
      start_date:      Time,
      end_date:        Time,
      gig_requirement: {type: Int32, default: 5},
      current:         {type: Bool, default: false},
    })

    def self.with_name(name)
      semester = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE name = ?", name, as: Semester
      semester || raise "No semester named #{name}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY start_date", as: Semester
    end

    @[GraphQL::Field(description: "The name of the semester")]
    def name : String
      @name
    end

    @[GraphQL::Field(name: "startDate", description: "When the semester starts")]
    def gql_start_date : String
      @start_date.to_s
    end

    @[GraphQL::Field(name: "endDate", description: "When the semester ends")]
    def gql_end_date : String
      @end_date.to_s
    end

    @[GraphQL::Field(description: "How many volunteer gigs are required for the semester")]
    def gig_requirement : Int32
      @gig_requirement
    end

    @[GraphQL::Field(description: "Whether this is the current semester")]
    def current : Bool
      @current
    end
  end

  @[GraphQL::Object]
  class Role
    include GraphQL::ObjectType

    class_getter table_name = "role"

    DB.mapping({
      name:         String,
      rank:         Int32,
      max_quantity: Int32,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY rank", as: Role
    end

    @[GraphQL::Field(description: "The name of the role")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "Used for ordering the positions (e.g. President before Ombudsman)")]
    def rank : Int32
      @rank
    end

    @[GraphQL::Field(description: "The maximum number of the position allowed to be held at once. If it is 0 or less, no maximum is enforced.")]
    def max_quantity : Int32
      @max_quantity
    end
  end

  @[GraphQL::Object]
  class MemberRole
    include GraphQL::ObjectType

    class_getter table_name = "member_role"

    DB.mapping({
      member: String,
      role:   String,
    })

    def self.current_officers
      CONN.query_all "SELECT * FROM #{@@table_name}", as: MemberRole
    end

    @[GraphQL::Field(description: "The email of the member holding the role")]
    def member : Models::Member
      Member.with_email @member
    end

    @[GraphQL::Field(description: "The name of the role being held")]
    def role : String
      @role
    end
  end

  class SectionType
    class_getter table_name = "section_type"

    DB.mapping({
      name: String,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: SectionType
    end
  end

  @[GraphQL::Object]
  class AbsenceRequest
    include GraphQL::ObjectType

    class_getter table_name = "absence_request"

    @[GraphQL::Enum(name: "AbsenceRequestState")]
    enum State
      PENDING
      APPROVED
      DENIED
    end

    class StateConverter
      def self.from_rs(val)
        case val
        when "pending"
          State::PENDING
        when "approved"
          State::APPROVED
        when "denied"
          State::DENIED
        else
          raise "Invalid absence request state returned from db: #{val}"
        end
      end
    end

    DB.mapping({
      member: String,
      event:  Int32,
      time:   {type: Time, default: Time.local},
      reason: String,
      state:  {type: State, converter: StateConverter},
    })

    def self.for_member_at_event(email, event_id)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE member = ? AND event = ?", email, event_id, as: AbsenceRequest
    end

    def self.for_semester(semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE semester = ? ORDER BY time", semester_name, as: AbsenceRequest
    end

    @[GraphQL::Field(description: "The member that requested an absence")]
    def member : Models::Member
      Member.with_email @member
    end

    @[GraphQL::Field(description: "The event they requested absence from")]
    def event : Models::Event
      Event.with_id @event
    end

    @[GraphQL::Field(name: "time", description: "The time this request was placed")]
    def gql_time : String
      @time.to_s
    end

    @[GraphQL::Field(description: "The reason the member petitioned for absence with")]
    def reason : String
      @reason
    end

    @[GraphQL::Field(description: "The current state of the request (See AbsenceRequestState)")]
    def state : Models::AbsenceRequest::State
      @state
    end
  end

  class Announcement
    class_getter table_name = "announcement"

    DB.mapping({
      id:       Int32,
      member:   String?,
      semester: String,
      time:     {type: Time, default: Time.local},
      content:  String,
      archived: {type: Bool, default: false},
    })
  end

  @[GraphQL::Object]
  class Attendance
    include GraphQL::ObjectType

    class_getter table_name = "attendance"

    DB.mapping({
      member:        String,
      event:         Int32,
      should_attend: {type: Bool, default: true},
      did_attend:    {type: Bool, default: false},
      confirmed:     {type: Bool, default: false},
      minutes_late:  {type: Int32, default: 0},
    })

    def self.for_member_at_event(member, event_id)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE member = ? && event = ?", member, event_id, as: Attendance
    end

    def self.for_member_at_event!(member, event_id)
      for_member_at_event(member, event_id) || raise "No attendance for member #{member} at event with id #{event_id}"
    end

    def self.for_event(event_id)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE event = ?", event_id, as: Attendance
    end

    @[GraphQL::Field(description: "The email of the member this attendance belongs to")]
    def member : Models::Member
      Member.with_email @member
    end

    @[GraphQL::Field(description: "Whether the member is expected to attend the event")]
    def should_attend : Bool
      @should_attend
    end

    @[GraphQL::Field(description: "Whether the member did attend the event")]
    def did_attend : Bool
      @did_attend
    end

    @[GraphQL::Field(description: "Whether the member confirmed that they would attend")]
    def confirmed : Bool
      @confirmed
    end

    @[GraphQL::Field(description: "How late the member was if they attended")]
    def minutes_late : Int32
      @minutes_late
    end

    @[GraphQL::Field]
    def absence_request : Models::AbsenceRequest?
      AbsenceRequest.for_member_at_event @member, @event
    end

    @[GraphQL::Field]
    def rsvp_issue : String?
      event = Event.with_id @event
      event.rsvp_issue_for member, self
    end

    @[GraphQL::Field]
    def approved_absence : Bool
      absence_request.try &.state == Models::AbsenceRequest::State::APPROVED
    end

    @[GraphQL::Field(name: "denyCredit")]
    def deny_credit? : Bool
      @should_attend && !@did_attend && !approved_absence
    end
  end

  @[GraphQL::Object]
  class Carpool
    include GraphQL::ObjectType

    class_getter table_name = "carpool"

    DB.mapping({
      id:     Int32,
      event:  Int32,
      driver: String,
    })

    def self.for_event(event_id)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE event = ?", event_id, as: Carpool
    end

    @[GraphQL::Field(name: "driver", description: "The driver of the carpool.")]
    def full_driver : Models::Member
      Member.with_email @driver
    end

    @[GraphQL::Field(description: "The passengers of the carpool.")]
    def passengers : Array(Models::Member)
      CONN.query_all "SELECT * FROM #{Member.table_name} WHERE email = \
        (SELECT member FROM #{RidesIn.table_name} WHERE carpool = ?)", @id, as: Member
    end
  end

  class RidesIn
    class_getter table_name = "rides_in"

    DB.mapping({
      member:  String,
      carpool: Int32,
    })
  end

  @[GraphQL::Object]
  class Fee
    include GraphQL::ObjectType

    class_getter table_name = "fee"

    DB.mapping({
      name:        String,
      description: String,
      amount:      {type: Int32, default: 0},
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: Fee
    end

    @[GraphQL::Field(description: "The short name of the fee")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "A longer description of what it is charging members for")]
    def description : String
      @description
    end

    @[GraphQL::Field(description: "The amount to charge members")]
    def amount : Int32
      @amount
    end
  end

  @[GraphQL::Object]
  class Document
    include GraphQL::ObjectType

    class_getter table_name = "google_docs"

    DB.mapping({
      name: String,
      url:  String,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: Document
    end

    @[GraphQL::Field(description: "The name of the document")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "A link to the document")]
    def url : String
      @url
    end
  end

  @[GraphQL::Object]
  class Uniform
    include GraphQL::ObjectType

    class_getter table_name = "uniform"

    DB.mapping({
      id:          Int32,
      name:        String,
      color:       String?,
      description: String?,
    })

    def is_valid?
      if color = u.color
        match = /#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})/i.match(color)
        !match.nil?
      else
        true
      end
    end

    def validate!
      raise "Uniform color must be a valid CSS color string" unless is_valid?
    end

    def self.with_id(id)
      uniform = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Uniform
      uniform || raise "No uniform with id #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: Uniform
    end

    @[GraphQL::Field(description: "The ID of the uniform")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The name of the uniform")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "The associated color of the uniform (In the format \"#HHH\", where \"H\" is a hex digit)")]
    def color : String?
      @color
    end

    @[GraphQL::Field(description: "The explanation of what to wear when wearing the uniform")]
    def description : String?
      @description
    end

    def self.with_id(id)
      uniform = CONN.query_one? "SELECT * from #{@@table_name} where id = ?", id, as: Uniform
      uniform || raise "No uniform with id #{id}"
    end
  end

  @[GraphQL::Object]
  class Minutes
    include GraphQL::ObjectType

    class_getter table_name = "minutes"

    DB.mapping({
      id:       Int32,
      name:     String,
      date:     Time,
      complete: {type: String?, key: "private"},
      public:   String?,
    })

    def self.with_id(id)
      minutes = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Minutes
      minutes || raise "No meeting minutes with id #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY date", as: Minutes
    end

    @[GraphQL::Field(description: "The id of the meeting minutes")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The name of the meeting")]
    def name : String
      @name
    end

    @[GraphQL::Field(name: "date", description: "When these notes were initially created")]
    def gql_date : String
      @date.to_s
    end

    @[GraphQL::Field(description: "The private, complete officer notes")]
    def private : String?
      @complete
    end

    @[GraphQL::Field(description: "The public, redacted notes visible by all members")]
    def public : String?
      @public
    end
  end

  @[GraphQL::Object]
  class Permission
    include GraphQL::ObjectType

    class_getter table_name = "permission"

    @[GraphQL::Enum(name: "PermissionType")]
    enum Type
      STATIC
      EVENT
    end

    DB.mapping({
      name:        String,
      description: String?,
      type:        {type: Type, default: Type::STATIC},
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: Permission
    end

    @[GraphQL::Field(description: "The name of the permission")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "A description of what the permission entails")]
    def description : String?
      @description
    end

    @[GraphQL::Field(description: "Whether the permission applies to a type of event or generally")]
    def type : Models::Permission::Type
      @type
    end
  end

  @[GraphQL::Object]
  class RolePermission
    include GraphQL::ObjectType

    class_getter table_name = "role_permission"

    DB.mapping({
      id:         Int32,
      role:       String,
      permission: String,
      event_type: String?,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name}", as: RolePermission
    end

    @[GraphQL::Field(description: "The ID of the role permission")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The name of the role this junction refers to")]
    def role : String
      @role
    end

    @[GraphQL::Field(description: "The name of the permission the role is awarded")]
    def permission : String
      @permission
    end

    @[GraphQL::Field(description: "The type of event the permission optionally applies to")]
    def event_type : String?
      @event_type
    end
  end

  class Todo
    class_getter table_name = "todo"

    DB.mapping({
      id:        Int32,
      text:      String,
      member:    String,
      completed: {type: Bool, default: false},
    })
  end

  class TransactionType
    class_getter table_name = "transaction_type"

    DB.mapping({
      name: String,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: TransactionType
    end
  end

  @[GraphQL::Object]
  class ClubTransaction
    include GraphQL::ObjectType

    class_getter table_name = "transaction"

    DB.mapping({
      id:          Int32,
      member:      String,
      time:        {type: Time, default: Time.local},
      amount:      Int32,
      description: String,
      semester:    String?,
      type:        String,
      resolved:    {type: Bool, default: false},
    })

    def self.for_semester(semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} \
        WHERE semester = ? ORDER BY time", semester_name, as: ClubTransaction
    end
  end

  class Session
    class_getter table_name = "session"

    DB.mapping({
      member: String,
      key:    String,
    })

    def self.for_token!(token)
      session = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE key = ?", token, as: Session
      session || raise "No login tied to the provided API token"
    end
  end

  @[GraphQL::Object]
  class Variable
    include GraphQL::ObjectType

    class_getter table_name = "variable"

    DB.mapping({
      key:   String,
      value: String,
    })

    def self.with_key(key)
      var = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE key = ?", key, as: Variable
      var || raise "No value set at key #{key}"
    end

    @[GraphQL::Field(description: "The name of the variable")]
    def key : String
      @key
    end

    @[GraphQL::Field(description: "The value of the variable")]
    def value : String
      @value
    end
  end
end
