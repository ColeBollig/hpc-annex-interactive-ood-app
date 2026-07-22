require "shellwords"

# Reads the `annex.record` file packaged inside a user's annex-setup tarball
# (produced by `htcondor annex create`) without fully extracting the archive.
#
# annex-setup.sh sources this same file and writes VERSION/STARTD_NOCLAIM_SHUTDOWN
# verbatim into the pilot's own HTCondor config -- neither value is ever
# modified before being applied, so reading it here at submit time is exactly
# as accurate as querying the running pilot, without needing to wait for the
# EP to start or guess at its on-node directory layout.
module AnnexRecord
  module_function

  # Returns a Hash of the KEY=VALUE pairs in annex.record (e.g.
  # {"VERSION" => "25.10.0", "STARTD_NOCLAIM_SHUTDOWN" => "300", ...}), or an
  # empty Hash if the tarball is missing, unreadable, or has no such file --
  # this is best-effort session-card info, never something to raise over.
  def read(tarball_path)
    return {} if tarball_path.to_s.strip.empty?

    escaped_path = Shellwords.escape(tarball_path)

    member = `tar -tf #{escaped_path} 2>/dev/null`
      .each_line(chomp: true)
      .find { |entry| entry == "annex.record" || entry.end_with?("/annex.record") }
    return {} unless member

    content = `tar -xO -f #{escaped_path} #{Shellwords.escape(member)} 2>/dev/null`
    return {} if content.strip.empty?

    content.each_line.each_with_object({}) do |line, record|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, _, value = line.partition("=")
      record[key.strip] = value.strip if key.strip.match?(/\A[A-Z_][A-Z0-9_]*\z/)
    end
  end
end
