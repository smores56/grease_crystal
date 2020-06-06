require "base64"
require "crystar"
require "gzip"
require "file_utils"

module Utils
  # MUSIC_BASE_PATH = Path["../httpsdocs/music/"]
  MUSIC_BASE_PATH = Path["./music/"]
  # FRONTEND_BASE_PATH = Path["../httpsdocs/glubhub/"]
  FRONTEND_BASE_PATH = Path["./glubhub/"]

  class FileUpload
    def initialize(@path : Path, @content : String)
    end

    def upload
      raise "file must have an extension" unless @path.extension

      File.open (MUSIC_BASE_PATH / @path.basename), "w+" do |f|
        f.truncate
        f << Base64.decode @content
      end
    end
  end

  def self.update_frontend(archive)
    Gzip::Reader.open archive do |gzip|
      Crystar::Reader.open gzip do |tar|
        tar.each_entry do |entry|
          # remove first segment since archive includes build/ folder
          file_name = Path.new Path[entry.name].parts[1..]
          path_to_write_to = FRONTEND_BASE_PATH / file_name

          containing_dir = path_to_write_to.dirname
          FileUtils.mkdir_p containing_dir if File.exists? containing_dir

          File.open path_to_write_to, "w+" do |f|
            IO.copy entry.io, f
          end
        end
      end
    end
  end
end
