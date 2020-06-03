require "graphql"
require "mysql"
require "../db"

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
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE name = ?", name, as: Semester
    end

    def self.with_name!(name)
      (with_name name) || raise "No semester named #{name}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY start_date", as: Semester
    end

    def self.create(form)
      if existing = with_name form.name
        raise "A semester already exists named #{form.name}"
      end

      CONN.exec "INSERT INTO #{@@table_name} \
        (name, start_date, end_date, gig_requirement) \
        VALUES (?, ?, ?, ?)",
        form.name, form.start_date, form.end_date, form.gig_requirement
    end

    def self.update(name, form)
      if name == form.name
        with_name! name
      else
        raise "Another semester is already named #{form.name}" if with_name form.name
      end

      CONN.exec "UPDATE #{@@table_name} SET \
        name = ?, start_date = ?, end_date = ?, gig_requirement = ? \
        WHERE name = ?",
        form.name, form.start_date, form.end_date, form.gig_requirement,
        name
    end

    def self.set_current(name)
      with_name! name

      CONN.exec "UPDATE #{@@table_name} SET current = false"
      CONN.exec "UPDATE #{@@table_name} SET current = true WHERE name = ?", name
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

    def self.with_name(name)
      doc = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE name = ?", name, as: Document
      doc || raise "No document named #{name}"
    end

    def self.create(name, url)
      if CONN.query_one? "SELECT name FROM #{@@table_name} WHERE name = ?", name, as: String
        raise "A document already exists named #{name}"
      end

      CONN.exec "INSERT INTO #{@@table_name} (name, url) VALUES (?, ?)", name, url
    end

    def self.update(name, url)
      # ensure document exists
      with_name name

      CONN.exec "UPDATE #{@@table_name} SET url = ? WHERE name = ?", url, name
    end

    def self.delete(name)
      CONN.exec "DELETE FROM #{@@table_name} WHERE name = ?", name
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
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Uniform
    end

    def self.with_id!(id)
      (with_id id) || raise "No uniform with id #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: Uniform
    end

    def self.default
      default = CONN.query_one? "SELECT * FROM #{@@table_name} ORDER BY name", as: Uniform
      default || raise "There are currently no uniforms"
    end

    def self.create(form)
      CONN.exec "INSERT INTO #{@@table_name} (name, color, description) VALUES (?, ?, ?)",
        form.name, form.color, form.description
      CONN.query_one "SELECT id FROM #{@@table_name} ORDER BY id DESC", as: Int32
    end

    def update(form)
      CONN.exec "UPDATE #{@@table_name} \
        SET name = ?, color = ?, description = ? \
        WHERE id = ?",
        form.name, form.color, form.description, @id

      @name, @color, @description = form.name, form.color, form.description
    end

    def delete
      CONN.exec "DELETE FROM  #{@@table_name} WHERE id = ?", @id
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
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: Minutes
    end

    def self.with_id!(id)
      (with_id id) || raise "No meeting minutes with id #{id}"
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY date", as: Minutes
    end

    def self.create(name)
      CONN.exec "INSERT INTO #{@@table_name} (name) VALUES (?)", name
      CONN.query_one "SELECT id FROM #{@@table_name} ORDER BY id DESC", as: Int32
    end

    def update(form)
      CONN.exec "UPDATE #{@@table_name} \
        SET name = ?, private = ?, public = ? \
        WHERE id = ?",
        form.name, form.complete, form.public, @id

      @name, @complete, @public = form.name, form.complete, form.public
    end

    def delete
      CONN.exec "DELETE FROM  #{@@table_name} WHERE id = ?", @id
    end

    def email
      # TODO: implement
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

    def self.set(key, value)
      if CONN.query_one? "SELECT key FROM #{@@table_name} WHERE key = ?", key, as: String
        CONN.exec "UPDATE #{@@table_name} SET value = ? WHERE key = ?", value, key
      else
        CONN.exec "INSERT INTO #{@@table_name} (key, value) VALUES (?, ?)", key, value
      end
    end

    def self.unset(key)
      CONN.exec "DELETE FROM #{@@table_name} WHERE key = ?", key
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
