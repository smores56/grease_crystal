require "./misc"
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
    })

    def self.with_id(id)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Event
    end

    def self.with_id!(id)
      (with_id id) || raise "No event with id #{id}"
    end

    def self.for_member_with_attendance(email, semester_name) : Array({Event, Attendance?})
      events = CONN.query_all "SELECT * FROM #{Event.table_name} WHERE semester = ?", semester_name, as: Event
      attendance = CONN.query_all "SELECT * FROM #{Attendance.table_name} WHERE member = ? AND event IN \
        (SELECT id FROM #{Event.table_name} WHERE semester = ?)", email, semester_name, as: Attendance

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

      if @call_time < Time.local.shift days: 1
        "Responses are closed for this event."
      end

      [TUTTI_GIG, SECTIONAL, REHEARSAL].each do |type|
        return "You cannot RSVP for #{type} events." if type == @type
      end

      nil
    end

    def self.create(form, from_request = nil)
      if release_time = form.event.release_time
        raise "Release time must be after call time" if release_time <= form.event.call_time
      end

      period, repeat_until = if r = form.repeat
                               {r.period, r.repeat_until}
                             else
                               raise "Must supply a repeat for new events"
                             end
      repeat_until = if period == Input::Period::NO
                       form.event.call_time
                     else
                       repeat_until || raise "Must supply a repeat until time if repeat is supplied"
                     end

      e = form.event
      call_and_release_times = repeat_event_times e.call_time, e.release_time, period, repeat_until
      raise "The repeat setting would render no events" if call_and_release_times.empty?

      call_and_release_times.each do |(call_time, release_time)|
        CONN.exec "INSERT INTO #{@@table_name} \
          (name, semester, type, call_time, release_time, points, \
           comments, location, gig_count, default_attend)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          e.name, e.semester, e.type, call_time, release_time, e.points,
          e.comments, e.location, e.gig_count, e.default_attend
      end

      new_ids = CONN.query_all "SELECT id FROM #{@@table_name} ORDER BY id DESC LIMIT ?",
        call_and_release_times.size, as: Int32
      new_ids.each { |id| Attendance.create_for_new_event id }

      if g = (form.gig || from_request.try &.build_new_gig)
        new_ids.each do |id|
          CONN.exec "INSERT INTO #{Gig.table_name} \
            (event, performance_time, uniform, contact_name, contact_email, \
             contact_phone, price, public, summary, description) \
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            id, g.performance_time, g.uniform, g.contact_name, g.contact_email,
            g.contact_phone, g.price, g.public, g.summary, g.description
        end
      end

      from_request.set_status GigRequest::Status::ACCEPTED if from_request

      new_ids.first
    end

    def self.repeat_event_times(call_time, release_time, period, repeat_until)
      pairs = [] of {Time, Time?}

      while call_time < repeat_until
        pairs << {call_time, release_time}

        case period
        when Input::Period::NO
          break
        when Input::Period::DAILY
          call_time = call_time.shift days: 1
          release_time = release_time.try &.shift days: 1
        when Input::Period::WEEKLY
          call_time = call_time.shift weeks: 1
          release_time = release_time.try &.shift weeks: 1
        when Input::Period::BIWEEKLY
          call_time = call_time.shift weeks: 2
          release_time = release_time.try &.shift weeks: 2
        when Input::Period::MONTHLY
          call_time = call_time.shift months: 1
          release_time = release_time.try &.shift months: 1
        when Input::Period::YEARLY
          call_time = call_time.shift years: 1
          release_time = release_time.try &.shift years: 1
        end
      end

      pairs
    end

    def self.update(id, form)
      event = Event.with_id! id

      raise "Gig fields must be present when updating gig events" if event.gig && !form.gig

      e = form.event
      CONN.exec "UPDATE #{@@table_name} SET \
        name = ?, semester = ?, type = ?, call_time = ?, release_time = ?, points = ?, \
        comments = ?, location = ?, gig_count = ?. default_attend = ? \
        WHERE id = ?",
        e.name, e.semester, e.type, e.call_time, e.release_time, e.points,
        e.comments, e.location, e.gig_count, e.default_attend, id

      if event.gig
        if g = form.gig
          CONN.exec "UPDATE #{Gig.table_name} SET \
            performance_time = ?, uniform = ?, contact_name = ?, contact_email = ?, \
            contact_phone = ?, price = ?, public = ?, summary = ?, description = ? \
            WHERE event = ?",
            g.performance_time, g.uniform, g.contact_name, g.contact_email,
            g.contact_phone, g.price, g.public, g.summary, g.description, id
        end
      end
    end

    def self.delete(id)
      Event.with_id! id

      CONN.exec "DELETE FROM #{@@table_name} WHERE id = ?", id
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
      Uniform.with_id! @uniform
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
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: GigRequest
    end

    def self.with_id!(id)
      (with_id id) || raise "No gig request with ID #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY time", as: GigRequest
    end

    def self.submit(form)
      CONN.exec "INSERT INTO #{@@table_name} \
        (name, organization, contact_name, contact_phone, \
        contact_email, start_time, location, comments) \
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        form.name, form.organization, form.contact_name, form.contact_phone,
        form.contact_email, form.start_time, form.location, form.comments

      CONN.query_one "SELECT id FROM #{@@table_name} ORDER BY id DESC", as: Int32
    end

    def set_status(status)
      if @status == status
        return
      elsif @status == Status::ACCEPTED
        raise "Cannot change the status of an accepted gig request"
      elsif @status == Status::DISMISSED && status == Status::ACCEPTED
        raise "Cannot directly accept a gig request if it is dismissed (please reopen it first)"
      elsif @status == Status::PENDING && status == Status::ACCEPTED && @event.nil?
        raise "Must create the event for the gig request first before marking it as accepted"
      else
        CONN.exec "UPDATE #{@@table_name} SET status = ? WHERE id = ?", status, @id

        @status = status
      end
    end

    def build_new_gig
      Input::NewGig.new @start_time.to_s, Uniform.default.id, @contact_name, @contact_email,
        @contact_phone, nil, false, nil, nil
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
      @event.try { |id| Event.with_id! id }
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

  @[GraphQL::Object]
  class PublicEvent
    include GraphQL::ObjectType

    def initialize(
      @id : Int32,
      @name : String,
      @time : Time,
      @location : String,
      @summary : String,
      @description : String,
      @invite : String
    )
    end

    # def self.all_for_current_semester
    #   events = CONN.query_all "SELECT * FROM #{Event.table_name} WHERE id IN \
    #     (SELECT event FROM #{Gig.table_name} WHERE public = true) \
    #     ORDER BY call_time", as: Event

    #   events.map do |event|
    #     calendar_url = build_calendar_url event
    # pub fn to_public(event: Event, gig: Gig) -> GreaseResult<PublicEvent> {
    #     if !gig.public {
    #         return Err(GreaseError::BadRequest(format!(
    #             "Event with id {} is not a public event.",
    #             event.id
    #         )));
    #     }

    #     let calendar_url = Self::build_calendar_url(&event, &gig);
    #     Ok(PublicEvent {
    #         id: event.id,
    #         name: event.name,
    #         time: gig.performance_time,
    #         location: event.location.unwrap_or_default(),
    #         summary: gig.summary.unwrap_or_default(),
    #         description: gig.description.unwrap_or_default(),
    #         invite: calendar_url,
    #     })
    # }

    # def self.build_calendar_url(event)
    #   gig = event.gig || raise "All public events must have gigs"

    # fn build_calendar_event(event: &Event, gig: &Gig) -> CalEvent {
    #     let end_time = event
    #         .release_time
    #         .unwrap_or(gig.performance_time + Duration::hours(1));
    #     let location = event.location.clone().unwrap_or_default();

    #     CalEvent::new()
    #         .summary(&event.name)
    #         .description(&gig.summary.clone().unwrap_or_default())
    #         .starts(Utc.from_local_datetime(&gig.performance_time).unwrap())
    #         .ends(Utc.from_local_datetime(&end_time).unwrap())
    #         .append_property(Property::new("LOCATION", &location).done())
    #         .done()
    # }

    # fn build_calendar(event: &Event, gig: &Gig) -> Calendar {
    #     let calendar_event = Self::build_calendar_event(event, gig);

    #     Calendar::from_iter(vec![calendar_event])
    # }

    # fn build_calendar_url(event: &Event, gig: &Gig) -> String {
    #     let calendar = Self::build_calendar(event, gig);
    #     let encoded_calendar = base64::encode_config(&calendar.to_string(), base64::URL_SAFE);

    #     format!("data:text/calendar;base64,{}", encoded_calendar)
    # }

    # pub fn to_public(event: Event, gig: Gig) -> GreaseResult<PublicEvent> {
    #     if !gig.public {
    #         return Err(GreaseError::BadRequest(format!(
    #             "Event with id {} is not a public event.",
    #             event.id
    #         )));
    #     }

    #     let calendar_url = Self::build_calendar_url(&event, &gig);
    #     Ok(PublicEvent {
    #         id: event.id,
    #         name: event.name,
    #         time: gig.performance_time,
    #         location: event.location.unwrap_or_default(),
    #         summary: gig.summary.unwrap_or_default(),
    #         description: gig.description.unwrap_or_default(),
    #         invite: calendar_url,
    #     })
    # }

    @[GraphQL::Field]
    def id : Int32
      @id
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    @[GraphQL::Field(name: "time")]
    def gql_time : String
      @time.to_s
    end

    @[GraphQL::Field]
    def location : String
      @location
    end

    @[GraphQL::Field]
    def summary : String
      @summary
    end

    @[GraphQL::Field]
    def description : String
      @description
    end

    @[GraphQL::Field]
    def invite : String
      @invite
    end
  end
end
