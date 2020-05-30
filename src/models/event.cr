require "./db"
require "../schema/context"

module Models
  @[GraphQL::Object]
  class EventType
    include GraphQL::ObjectType

    class_getter table_name = "event_type"

    DB.mapping({
      name:   String,
      weight: Int32,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: EventType
    end

    @[GraphQL::Field(description: "The name of the type of event")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "How many points this type is worth")]
    def weight : Int32
      @weight
    end
  end

  @[GraphQL::Object]
  class Event
    include GraphQL::ObjectType

    REHEARSAL     = "Rehearsal"
    SECTIONAL     = "Sectional"
    VOLUNTEER_GIG = "Volunteer Gig"
    TUTTI_GIG     = "Tutti Gig"
    OMBUDS        = "Ombuds"
    OTHER         = "Other"

    class_getter table_name = "event"

    DB.mapping({
      id:             Int32,
      name:           String,
      semester:       String,
      type:           String,
      call_time:      Time,
      release_time:   Time?,
      points:         Int32,
      comments:       String?,
      location:       String?,
      gig_count:      {type: Bool, default: true},
      default_attend: {type: Bool, default: true},
      section:        String?,
    })

    def self.with_id(id)
      event = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Event
      event || raise "No event with id #{id}"
    end

    def self.for_member_with_attendance(email, semester_name) : Array({Event, Attendance?})
      events = CONN.query_all "SELECT * FROM #{Event.table_name} WHERE semester = ?", semester_name, as: Event
      attendance = CONN.query_all "SELECT * FROM #{Attendance.table_name} WHERE member = ? AND event IN \
        (SELECT * FROM #{Event.table_name} WHERE semester = ?)", email, semester_name, as: Attendance

      events.map do |event|
        {event, attendance.find { |a| a.event == event.id }}
      end
    end

    def self.for_semester(semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE semester = ?", semester_name, as: Event
    end

    def is_gig?
      @type == TUTTI_GIG || @type == VOLUNTEER_GIG
    end

    def ensure_no_rsvp_issue!(member, attendance)
      rsvp_issue = rsvp_issue_for member, attendance
      raise rsvp_issue if rsvp_issue
    end

    def rsvp_issue_for(member, attendance : Attendance?)
      if !member.is_active?
        return "Member must be active to RSVP to events."
      elsif attendance && !attendance.should_attend
        return nil
      end

      twenty_four_hours_from_now = Time.local + Time::Span.new 1, 0, 0, 0
      if @call_time < twenty_four_hours_from_now
        "Responses are closed for this event."
      end

      [TUTTI_GIG, SECTIONAL, REHEARSAL].each do |type|
        return "You cannot RSVP for #{type} events." if type == @type
      end

      nil
    end

    @[GraphQL::Field(description: "The ID of the event")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The name of the event")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "The name of the semester this event belongs to")]
    def semester : String
      @semester
    end

    @[GraphQL::Field(description: "The type of the event (see EventType)")]
    def type : String
      @type
    end

    @[GraphQL::Field(name: "callTime", description: "When members are expected to arrive to the event")]
    def gql_call_time : String
      @call_time.to_s
    end

    @[GraphQL::Field(name: "releaseTime", description: "When members are probably going to be released")]
    def gql_release_time : String?
      @release_time.try &.to_s
    end

    @[GraphQL::Field(description: "How many points attendance of this event is worth")]
    def points : Int32
      @points
    end

    @[GraphQL::Field(description: "General information or details about this event")]
    def comments : String?
      @comments
    end

    @[GraphQL::Field(description: "Where this event will be held")]
    def location : String?
      @location
    end

    @[GraphQL::Field(description: "Whether this event counts toward the volunteer gig count for the semester")]
    def gig_count : Bool
      @gig_count
    end

    @[GraphQL::Field(description: "Whether members are assumed to attend (most events)")]
    def default_attend : Bool
      @default_attend
    end

    @[GraphQL::Field(description: "If this event is for one singing section only, this denotes which one (e.g. old sectionals)")]
    def section : String?
      @section
    end

    @[GraphQL::Field]
    def gig : Models::Gig?
      Gig.for_event @id
    end

    @[GraphQL::Field]
    def user_attendance(context : UserContext) : Models::Attendance
      Attendance.for_member_at_event! context.user!.email, @id
    end

    @[GraphQL::Field]
    def attendance(member : String) : Models::Attendance
      Attendance.for_member_at_event! member, @id
    end

    @[GraphQL::Field]
    def all_attendance : Array(Models::Attendance)
      Attendance.for_event @id
    end

    @[GraphQL::Field]
    def carpools : Array(Models::Carpool)
      Carpool.for_event @id
    end

    @[GraphQL::Field]
    def setlist : Array(Models::Song)
      Song.setlist_for_event @id
    end
  end

  @[GraphQL::Object]
  class Gig
    include GraphQL::ObjectType

    class_getter table_name = "gig"

    DB.mapping({
      event:            Int32,
      performance_time: Time,
      uniform:          Int32,
      contact_name:     String?,
      contact_email:    String?,
      contact_phone:    String?,
      price:            Int32?,
      public:           {type: Bool, default: false},
      summary:          String?,
      description:      String?,
    })

    def self.for_event(event_id)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE event = ?", event_id, as: Gig
    end

    @[GraphQL::Field(description: "The ID of the event this gig belongs to")]
    def event : Int32
      @event
    end

    @[GraphQL::Field(name: "performanceTime", description: "When members are expected to actually perform")]
    def gql_performance_time : String
      @performance_time.to_s
    end

    @[GraphQL::Field(description: "The uniform for this gig")]
    def uniform : Models::Uniform
      Uniform.with_id @uniform
    end

    @[GraphQL::Field(description: "The name of the contact for this gig")]
    def contact_name : String?
      @contact_name
    end

    @[GraphQL::Field(description: "The email of the contact for this gig")]
    def contact_email : String?
      @contact_email
    end

    @[GraphQL::Field(description: "The phone of the contact for this gig")]
    def contact_phone : String?
      @contact_phone
    end

    @[GraphQL::Field(description: "The price we are charging for this gig")]
    def price : Int32?
      @price
    end

    @[GraphQL::Field(description: "Whether this gig is visible on the external website")]
    def public : Bool
      @public
    end

    @[GraphQL::Field(description: "A summary of this event for the external site (if it is public)")]
    def summary : String?
      @summary
    end

    @[GraphQL::Field(description: "A description of this event for the external site (if it is public)")]
    def description : String?
      @description
    end
  end

  @[GraphQL::Object]
  class GigRequest
    include GraphQL::ObjectType

    class_getter table_name = "gig_request"

    @[GraphQL::Enum(name: "GigRequestStatus")]
    enum Status
      PENDING
      ACCEPTED
      DISMISSED
    end

    DB.mapping({
      id:            Int32,
      event:         Int32?,
      time:          {type: Time, default: Time.local},
      name:          String,
      organization:  String,
      contact_name:  String,
      contact_phone: String,
      contact_email: String,
      start_time:    Time,
      location:      String,
      comments:      String?,
      status:        {type: Status, default: Status::PENDING},
    })

    def self.with_id(id)
      request = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: GigRequest
      request || raise "No gig request with ID #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY time", as: GigRequest
    end

    @[GraphQL::Field(description: "The ID of the gig request")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(name: "time", description: "When the gig request was placed")]
    def gql_time : String
      @time.to_s
    end

    @[GraphQL::Field(description: "The name of the potential event")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "The organization requesting a performance from the Glee Club")]
    def organization : String
      @organization
    end

    @[GraphQL::Field(description: "If and when an event is created from a request, this is the event")]
    def event : Models::Event?
      @event.try { |id| Event.with_id id }
    end

    @[GraphQL::Field(description: "The name of the contact for the potential event")]
    def contact_name : String
      @contact_name
    end

    @[GraphQL::Field(description: "The email of the contact for the potential event")]
    def contact_email : String
      @contact_email
    end

    @[GraphQL::Field(description: "The phone number of the contact for the potential event")]
    def contact_phone : String
      @contact_phone
    end

    @[GraphQL::Field(name: "startTime", description: "When the event will probably happen")]
    def gql_start_time : String
      @start_time.to_s
    end

    @[GraphQL::Field(description: "Where the event will be happening")]
    def location : String
      @location
    end

    @[GraphQL::Field(description: "Any comments about the event")]
    def comments : String?
      @comments
    end

    @[GraphQL::Field(description: "The current status of whether the request was accepted")]
    def status : Models::GigRequest::Status
      @status
    end
  end

  @[GraphQL::Object(name: "Carpool")]
  class EventCarpool
    def initialize(@driver : MemberForSemester, @passengers : Array(MemberForSemester))
    end

    @[GraphQL::Field(description: "The driver of the carpool")]
    def driver : Models::MemberForSemester
      @driver
    end

    @[GraphQL::Field(description: "The passengers of the carpool")]
    def passengers : Array(Models::MemberForSemester)
      @passengers
    end
  end
end
