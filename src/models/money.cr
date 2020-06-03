require "dotenv"
require "graphql"
require "mysql"
require "../db"

module Models
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

    def self.with_name(name)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE name = ?", name, as: Fee
    end

    def self.with_name!(name)
      (with_name name) || raise "No fee named #{name}"
    end

    def set_amount(new_amount)
      CONN.exec "UPDATE #{@@table_name} SET amount = ? WHERE name = ?", new_amount, @name

      @amount = new_amount
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

  class TransactionType
    class_getter table_name = "transaction_type"

    DB.mapping({
      name: String,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY name", as: TransactionType
    end

    def self.with_name(name)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE name = ?", name, as: TransactionType
    end

    def self.with_name!(name)
      (with_name name) || raise "No transaction type named #{name}"
    end
  end

  @[GraphQL::Object]
  class ClubTransaction
    include GraphQL::ObjectType

    DUES_NAME             = "Dues"
    DUES_DESCRIPTION      = "Semesterly Dues"
    LATE_DUES_DESCRIPTION = "Late Dues"

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

    def self.with_id(id)
      CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: ClubTransaction
    end

    def self.with_id!(id)
      (with_id id) || raise "No transaction with id #{id}"
    end

    def self.for_semester(semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} \
        WHERE semester = ? ORDER BY time", semester_name, as: ClubTransaction
    end

    def self.for_member_during_semester(email, semester_name)
      CONN.query_all "SELECT * FROM #{@@table_name} \
        WHERE semester = ? AND member = ? ORDER BY time", semester_name, email, as: ClubTransaction
    end

    def self.add_batch(batch)
      type = TransactionType.with_name! batch.type

      batch.members.each do |email|
        CONN.exec "INSERT INTO #{@@table_name} \
          (member, amount, type, description, semester) \
          VALUES (?, ?, ?, ?, ?)",
          email, batch.amount, type.name, batch.description, Semester.current.name
      end
    end

    def resolve(resolved)
      CONN.exec "UPDATE #{@@table_name} SET resolved = ? WHERE id = ?",
        resolved, @id

      @resolved = resolved
    end

    @[GraphQL::Field(description: "The ID of the transaction")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The email of the member this transaction was charged to")]
    def member : Models::Member
      Member.with_email @member
    end

    @[GraphQL::Field(name: "time", description: "When this transaction was charged")]
    def gql_time : String
      @time.to_s
    end

    @[GraphQL::Field(description: "How much this transaction was for")]
    def amount : Int32
      @amount
    end

    @[GraphQL::Field(description: "A description of what the member was charged for specifically")]
    def description : String
      @description
    end

    @[GraphQL::Field(description: "Optionally, the name of the semester this transaction was made during")]
    def semester : String?
      @semester
    end

    @[GraphQL::Field(description: "The name of the type of transaction")]
    def type : String
      @type
    end

    @[GraphQL::Field(description: "Whether the member has paid the amount requested in this transaction")]
    def resolved : Bool
      @resolved
    end
  end
end
