require "base64"

module Utils
  # MUSIC_BASE_PATH = Path["../httpsdocs/music/"]
  MUSIC_BASE_PATH = Path["./music/"]

  class FileUpload
    def initialize(@path : String, @content : String)
    end

    def upload
      raise "file must have an extension" unless Path[@path].extension

      path = MUSIC_BASE_PATH / Path[@path].basename
      file = File.open path, "w+"

      file.truncate
      file << Base64.decode @content
    end
  end
end
