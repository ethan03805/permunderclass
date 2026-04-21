require "json"
require "open3"

class VideoMetadata
  Result = Struct.new(:codec_name, :duration_seconds, :available, keyword_init: true) do
    def available?
      available
    end
  end

  def self.inspect(blob_or_path)
    return inspect_path(blob_or_path) if blob_or_path.is_a?(String) || blob_or_path.is_a?(Pathname)

    blob_or_path.open do |file|
      inspect_path(file.path)
    end
  rescue Errno::ENOENT, JSON::ParserError
    Result.new(available: false)
  end

  def self.inspect_path(path)
    stdout, _stderr, status = Open3.capture3(
      "ffprobe",
      "-v", "error",
      "-print_format", "json",
      "-show_streams",
      "-show_format",
      path.to_s
    )

    return Result.new(available: false) unless status.success?

    payload = JSON.parse(stdout)
    streams = Array(payload["streams"])
    video_stream = streams.find { |stream| stream["codec_type"] == "video" }
    duration_seconds = payload.dig("format", "duration").presence || video_stream&.dig("duration")

    Result.new(
      available: video_stream.present?,
      codec_name: video_stream&.dig("codec_name")&.downcase,
      duration_seconds: duration_seconds.to_f
    )
  rescue Errno::ENOENT, JSON::ParserError
    Result.new(available: false)
  end
end
