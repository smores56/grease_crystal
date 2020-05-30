require "graphql"
require "./models"
require "./grades"

module Models
  @[GraphQL::Object]
  class Member
    include GraphQL::ObjectType

    class_getter table_name = "member"

    @semesters : Hash(String, ActiveSemester)?

    DB.mapping({
      email:                String,
      first_name:           String,
      preferred_name:       String?,
      last_name:            String,
      pass_hash:            String,
      phone_number:         String,
      picture:              String?,
      passengers:           {type: Int32, default: 0},
      location:             String,
      on_campus:            Bool?,
      about:                String?,
      major:                String?,
      minor:                String?,
      hometown:             String?,
      arrived_at_tech:      Int32?,
      gateway_drug:         String?,
      conflicts:            String?,
      dietary_restrictions: String?,
    })

    def self.with_email(email)
      member = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE email = ?", email, as: Member
      member || raise "No member with email #{email}"
    end

    def self.load_from_token(token)
      session = Session.for_token! token
      Member.with_email session.member
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY last_name, first_name", as: Member
    end

    def is_active?
      get_semester(Semester.current.name)
    end

    def get_semester(semester_name)
      @semesters = ActiveSemester.all_for_member @email if @semesters.nil?
      @semesters.not_nil![semester_name]?
    end

    def get_semester!(semester_name)
      get_semester(semester_name) || raise "#{full_name} was not active during #{semester_name}"
    end

    # def roles
    #   Conn.
    # end

    # has_many roles : Role

    @[GraphQL::Field(description: "The member's email, which must be unique")]
    def email : String
      @email
    end

    @[GraphQL::Field(description: "The member's first name")]
    def first_name : String
      @first_name
    end

    @[GraphQL::Field(description: "The member's nick name")]
    def preferred_name : String?
      @preferred_name
    end

    @[GraphQL::Field(description: "The member's last name")]
    def last_name : String
      @last_name
    end

    @[GraphQL::Field(description: "The member's full name")]
    def full_name : String
      "#{@preferred_name || @first_name} #{@last_name}"
    end

    @[GraphQL::Field(description: "The member's phone number")]
    def phone_number : String
      @phone_number
    end

    @[GraphQL::Field(description: "An optional link to a profile picture for the member")]
    def picture : String?
      @picture
    end

    @[GraphQL::Field(description: "An optional link to a profile picture for the member")]
    def passengers : Int32
      @passengers
    end

    @[GraphQL::Field(description: "Where the member lives")]
    def location : String
      @location
    end

    @[GraphQL::Field(description: "Whether the member currently lives on campus (assumed false)")]
    def on_campus : Bool?
      @on_campus
    end

    @[GraphQL::Field(description: "The member's academic major")]
    def major : String?
      @major
    end

    @[GraphQL::Field(description: "The member's academic minor")]
    def minor : String?
      @minor
    end

    @[GraphQL::Field(description: "Where the member originally comes from")]
    def hometown : String?
      @hometown
    end

    @[GraphQL::Field(description: "What year the member arrived at Tech (e.g. 2012)")]
    def arrived_at_tech : Int32?
      @arrived_at_tech
    end

    @[GraphQL::Field(description: "What brought the member to Glee Club")]
    def gateway_drug : String?
      @gateway_drug
    end

    @[GraphQL::Field(description: "What conflicts during the week the member may have")]
    def conflicts : String?
      @conflicts
    end

    @[GraphQL::Field(description: "What dietary restrictions the member may have")]
    def dietary_restrictions : String?
      @dietary_restrictions
    end

    @[GraphQL::Field(description: "The name of the semester they were active during")]
    def semester : String?
      get_semester(Semester.current.name).try &.semester
    end

    @[GraphQL::Field(description: "Whether they were in the class or the club")]
    def enrollment : Models::ActiveSemester::Enrollment?
      get_semester(Semester.current.name).try &.enrollment
    end

    @[GraphQL::Field(description: "Which section the member sang in")]
    def section : String?
      get_semester(Semester.current.name).try &.section
    end

    @[GraphQL::Field(description: "The officer positions currently held by the member")]
    def positions : Array(String)
      [] of String
    end

    @[GraphQL::Field(description: "The permissions held currently by the member")]
    def permissions : Array(Models::MemberPermission)
      [] of MemberPermission
    end

    @[GraphQL::Field(description: "The grades for the member in the given semester (default the current semester)")]
    def grades : Models::Grades
      Grades.for_member self, Semester.current
    end

    @[GraphQL::Field(description: "All of the member's transactions for their entire time in Glee Club")]
    def transaction : Array(Models::ClubTransaction)
      [] of Models::ClubTransaction
    end
  end

  @[GraphQL::Object]
  class ActiveSemester
    include GraphQL::ObjectType

    class_getter table_name = "active_semester"

    @[GraphQL::Enum]
    enum Enrollment
      CLASS
      CLUB
    end

    DB.mapping({
      member:     String,
      semester:   String,
      enrollment: {type: Enrollment, default: Enrollment::CLUB},
      section:    String?,
    })

    def self.all_for_member(email)
      semesters = CONN.query_all "SELECT * FROM #{@@table_name} WHERE member = ?", email, as: ActiveSemester
      semester_map = {} of String => ActiveSemester
      semesters.each { |semester| semester_map[semester.semester] = semester }

      semester_map
    end

    def self.for_semester(email, semester)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE member = ? AND SEMESTER = ?", email, semester, as: ActiveSemester
    end
  end
end
