require "graphql"
require "mysql"
require "./db"
require "./event"

module Models
  @[GraphQL::Object]
  class Song
    include GraphQL::ObjectType

    class_getter table_name = "song"

    @[GraphQL::Enum]
    enum Pitch
      A_FLAT
      A
      A_SHARP
      B_FLAT
      B
      B_SHARP
      C_FLAT
      C
      C_SHARP
      D_FLAT
      D
      D_SHARP
      E_FLAT
      E
      E_SHARP
      F_FLAT
      F
      F_SHARP
      G_FLAT
      G
      G_SHARP
    end

    @[GraphQL::Enum]
    enum Mode
      MAJOR
      MINOR
    end

    DB.mapping({
      id:             Int32,
      title:          String,
      info:           String?,
      current:        {type: Bool, default: false},
      key:            Models::Song::Pitch?,
      starting_pitch: Models::Song::Pitch?,
      mode:           Models::Song::Mode?,
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY title", as: Song
    end

    def self.with_id(song_id)
      song = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", song_id, as: Song
      song || raise "No song with id #{song_id}"
    end

    def self.setlist_for_event(event_id)
      CONN.query_all "SELECT * FROM #{@@table_name} \
        INNER JOIN #{GigSong.table_name} ON #{@@table_name}.id = #{GigSong.table_name}.song
        WHERE #{GigSong.table_name}.event = ?
        ORDER BY #{GigSong.table_name}.order ASC", event_id, as: Song
    end

    def self.all_public
      all_links = SongLink.all

      Song.all.map do |song|
        videos = all_links
          .select { |link| link.type == SongLink::PERFORMANCES }
          .map { |link| PublicVideo.new link.name, link.target }

        PublicSong.new song.title, song.current, videos
      end
    end

    @[GraphQL::Field(description: "The ID of the song")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The title of the song")]
    def title : String
      @title
    end

    @[GraphQL::Field(description: "Any information related to the song (minor changes to the music, who wrote it, soloists, etc.)")]
    def info : String?
      @info
    end

    @[GraphQL::Field(description: "Whether it is in this semester's repertoire")]
    def current : Bool
      @current
    end

    @[GraphQL::Field(description: "The key of the song")]
    def key : Models::Song::Pitch?
      @key
    end

    @[GraphQL::Field(description: "The starting pitch for the song")]
    def starting_pitch : Models::Song::Pitch?
      @starting_pitch
    end

    @[GraphQL::Field(description: "The mode of the song (Major or Minor)")]
    def mode : Models::Song::Mode?
      @mode
    end

    @[GraphQL::Field(description: "The links connected to the song sorted into sections")]
    def links : Array(Models::SongLinkSection)
      all_links = SongLink.for_song @id
      all_types = MediaType.all

      all_types.map do |type|
        SongLinkSection.new type.name, all_links.select { |l| l.type == type.name }
      end
    end
  end

  @[GraphQL::Object]
  class SongLinkSection
    include GraphQL::ObjectType

    def initialize(@name : String, @links : Array(SongLink))
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    @[GraphQL::Field]
    def links : Array(Models::SongLink)
      @links
    end
  end

  class GigSong
    class_getter table_name = "gig_song"

    DB.mapping({
      event: Int32,
      song:  Int32,
      order: Int32,
    })
  end

  @[GraphQL::Object]
  class MediaType
    include GraphQL::ObjectType

    class_getter table_name = "media_type"

    @[GraphQL::Enum]
    enum StorageType
      LOCAL
      REMOTE
    end

    class StorageTypeConverter
      def self.from_rs(val)
        case val
        when "local"
          StorageType::LOCAL
        when "remote"
          StorageType::REMOTE
        else
          raise "Invalid media storage type returned from db: #{val}"
        end
      end
    end

    DB.mapping({
      name:    String,
      order:   Int32,
      storage: {type: StorageType, converter: StorageTypeConverter},
    })

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name} ORDER BY order ASC", as: MediaType
    end

    @[GraphQL::Field(description: "The name of the type of media")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "The order of where this media type appears in a song's link section")]
    def order : Int32
      @order
    end

    @[GraphQL::Field(description: "The type of storage that this type of media points to")]
    def storage : Models::MediaType::StorageType
      @storage
    end
  end

  @[GraphQL::Object]
  class SongLink
    include GraphQL::ObjectType

    PERFORMANCES = "Performances"

    class_getter table_name = "song_link"

    DB.mapping({
      id:     Int32,
      song:   Int32,
      type:   String,
      name:   String,
      target: String,
    })

    def self.with_id(id)
      link = CONN.query_one? "SELECT * FROM #{@@table_name} WHERE id = ?", id, as: SongLink
      link || raise "No song link with id #{id}"
    end

    def self.for_song(song_id)
      CONN.query_all "SELECT * FROM #{@@table_name} WHERE song = ?", song_id, as: SongLink
    end

    def self.all
      CONN.query_all "SELECT * FROM #{@@table_name}", as: SongLink
    end

    @[GraphQL::Field(description: "The ID of the song link")]
    def id : Int32
      @id
    end

    @[GraphQL::Field(description: "The ID of the song this link belongs to")]
    def song : Int32
      @song
    end

    @[GraphQL::Field(description: "The type of this link (e.g. MIDI)")]
    def type : String
      @type
    end

    @[GraphQL::Field(description: "The name of this link")]
    def name : String
      @name
    end

    @[GraphQL::Field(description: "The target this link points to")]
    def target : String
      @target
    end
  end

  @[GraphQL::Object]
  class PublicSong
    include GraphQL::ObjectType

    def initialize(@title : String, @current : Bool, @videos : Array(PublicVideo))
    end

    @[GraphQL::Field]
    def title : String
      @title
    end

    @[GraphQL::Field]
    def current : Bool
      @current
    end

    @[GraphQL::Field]
    def videos : Array(Models::PublicVideo)
      @videos
    end
  end

  @[GraphQL::Object]
  class PublicVideo
    include GraphQL::ObjectType

    def initialize(@title : String, @url : String)
    end

    @[GraphQL::Field]
    def title : String
      @title
    end

    @[GraphQL::Field]
    def url : String
      @url
    end
  end
end
