require "graphql"
require "mysql"
require "uuid"
require "crypto/bcrypt"
require "./grades"
require "../email"

Password = Crypto::Bcrypt::Password

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

    def self.active_during(semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE email IN \
        (SELECT member FROM #{ActiveSemester.table_name} WHERE semester = ?)", semester_name, as: Member
    end

    def self.valid_login?(form)
      pass_hash = CONN.query_one? "SELECT pass_hash FROM #{@@table_name} \
        WHERE email = ?", form.email, as: String
      pass_hash && Crypto::Bcrypt::Password.new(raw_hash: pass_hash).verify(form.pass_hash)
    end

    def is_active?
      get_semester(Semester.current.name)
    end

    def get_semester(semester_name)
      ActiveSemester.for_semester @email, semester_name
    end

    def get_semester!(semester_name)
      get_semester(semester_name) || raise "#{full_name} was not active during #{semester_name}"
    end

    def self.register(form)
      if CONN.query_one? "SELECT email FROM #{@@table_name} WHERE email = ?", form.email, as: String
        raise "Another member already has the email #{form.email}"
      end

      pass_hash = Password.create(form.pass_hash, cost: 10).to_s

      CONN.exec "INSERT INTO #{@@table_name} \
        (email, first_name, preferred_name, last_name, pass_hash, phone_number, \
         picture, passengers, location, on_campus, about, major, minor, hometown, \
         arrived_at_tech, gateway_drug, conflicts, dietary_restrictions)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        form.email, form.first_name, form.preferred_name, form.last_name, pass_hash,
        form.phone_number, form.picture, form.passengers, form.location, form.on_campus,
        form.about, form.major, form.minor, form.hometown, form.arrived_at_tech,
        form.gateway_drug, form.conflicts, form.dietary_restrictions
    end

    def self.register_for_current_semester(member, form)
      ActiveSemester.create_for_member member, form, Semester.current

      CONN.exec "UPDATE #{@@table_name} \
        SET location = ?, on_campus = ?, conflicts = ?, dietary_restrictions = ? \
        WHERE email = ?", form.location, form.on_campus, form.conflicts,
        form.dietary_restrictions, member.email
    end

    def self.update(member, form, as_self)
      if member.email != form.email
        existing_email = CONN.query_one? "SELECT email FROM #{@@table_name} WHERE email = ?", form.email, as: String
        raise "Cannot change email to #{form.email}, as another member has that email" if existing_email
      end

      pass_hash = if member_hash = form.pass_hash
                    if as_self
                      Password.create(member_hash, cost: 10).to_s
                    else
                      raise "Only members themselves can change their own passwords"
                    end
                  else
                    member.pass_hash
                  end

      CONN.exec "UPDATE #{@@table_name} SET \
        email = ?, first_name = ?, preferred_name = ?, last_name = ?, \
        phone_number = ?, picture = ?, passengers = ?, location = ?, \
        about = ?, major = ?, minor = ?, hometown = ?, arrived_at_tech = ?, \
        gateway_drug = ?, conflicts = ?, dietary_restrictions = ?, pass_hash = ?",
        form.email, form.first_name, form.preferred_name, form.last_name,
        form.phone_number, form.picture, form.passengers, form.location,
        form.about, form.major, form.minor, form.hometown, form.arrived_at_tech,
        form.gateway_drug, form.conflicts, form.dietary_restrictions, pass_hash

      ActiveSemester.update form.email, Semester.current, form.enrollment, form.section
    end

    def self.delete(email)
      # ensure member exists
      Member.with_email email

      CONN.exec "DELETE FROM #{@@table_name} WHERE email = ?", email
    end

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

    @[GraphQL::Field(description: "The name of the semester they were active during")]
    def semesters : Array(Models::ActiveSemester)
      (ActiveSemester.all_for_member @email).sort_by &.semester
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
      (Role.for_member @email).map &.name
    end

    @[GraphQL::Field(description: "The permissions held currently by the member")]
    def permissions : Array(Models::MemberPermission)
      MemberPermission.for_member @email
    end

    @[GraphQL::Field(description: "The grades for the member in the given semester (default the current semester)")]
    def grades : Models::Grades
      Grades.for_member self, Semester.current
    end

    @[GraphQL::Field(description: "All of the member's transactions for their entire time in Glee Club")]
    def transaction : Array(Models::ClubTransaction)
      ClubTransaction.for_member_during_semester @email, Semester.current.name
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

      def self.parse(val)
        case val
        when "CLASS"
          CLASS
        when "CLUB"
          CLUB
        else
          raise "Unknown enrollment variant: #{val}"
        end
      end
    end

    DB.mapping({
      member:     String,
      semester:   String,
      enrollment: {type: Enrollment, default: Enrollment::CLUB},
      section:    String?,
    })

    def self.all_for_member(email)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE member = ?", email, as: ActiveSemester
    end

    def self.for_semester(email, semester_name)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE member = ? AND SEMESTER = ?",
        email, semester_name, as: ActiveSemester
    end

    def self.create_for_member(member, form, semester)
      if member.get_semester(semester.name)
        raise "#{member.full_name} is already active for the current semester"
      end

      CONN.exec "INSERT INTO #{@@table_name} (member, semester, enrollment, section)
        VALUES (?, ?, ?, ?)", member.email, semester.name, form.enrollment, form.section
    end

    def self.update(email, semester_name, enrollment, section)
      active_semester = for_semester email, semester_name

      if enrollment
        if active_semester
          CONN.exec "UPDATE #{@@table_name} SET enrollment = ?, section = ? \
            WHERE member = ? AND semester = ?", enrollment, section, email, semester_name
        else
          CONN.exec "INSERT INTO #{@@table_name} (member, semester, enrollment, section)
            VALUES (?, ?, ?, ?)", email, semester_name, enrollment, section
        end
      elsif active_semester
        CONN.exec "DELETE FROM #{@@table_name} WHERE member = ? AND SEMESTER = ?", email, semester_name
      end
    end

    @[GraphQL::Field(description: "The grades for the member in the given semester")]
    def grades : Models::Grades
      Grades.for_member (Member.with_email @member), (Semester.with_name! @semester)
    end

    @[GraphQL::Field]
    def semester : String
      @semester
    end

    @[GraphQL::Field]
    def enrollment : Models::ActiveSemester::Enrollment
      @enrollment
    end
  end
end
