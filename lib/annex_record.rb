require "shellwords"
require "tempfile"

# Reads the `annex.record` file packaged inside a user's annex-setup tarball
# (produced by `htcondor annex create`) without fully extracting the archive.
module AnnexRecord
  module_function

  # Only VERSION/STARTD_NOCLAIM_SHUTDOWN are ever surfaced beyond the raw
  # tarball read (see `effective` below) -- keep this list in sync with
  # anything info.html.erb actually displays.
  OVERRIDABLE_KEYS = %w[VERSION STARTD_NOCLAIM_SHUTDOWN].freeze

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

  # Like `read`, but simulates the exact override precedence annex-setup.sh
  # applies: it sources the tarball's annex.record, then -- if present --
  # sources the user's own ~/.condor/annex_config on top of it, BEFORE using
  # VERSION (to pick which HTCondor build to download) or writing
  # STARTD_NOCLAIM_SHUTDOWN into the pilot's actual config. A plain tarball
  # read alone would silently miss such an override: ~/.condor/annex_config
  # is a supported user customization point (see USER-STEPS.md, documented
  # there for modules/SCRATCH) that isn't restricted to only those uses --
  # nothing stops a user from also overriding VERSION/STARTD_NOCLAIM_SHUTDOWN
  # there, and if they have, the tarball's own value is stale.
  #
  # This runs the user's own ~/.condor/annex_config exactly as their real job
  # eventually will anyway (same user, same file), just earlier -- so it adds
  # no new trust boundary, only an extra invocation. Wrapped in `timeout` so
  # a slow/hanging annex_config can't stall job submission itself.
  def effective(tarball_path)
    record = read(tarball_path)
    return record if record.empty?

    config_path = File.join(Dir.home, ".condor", "annex_config")

    Tempfile.create("annex_record") do |file|
      record.each { |key, value| file.puts("#{key}=#{value}") }
      file.flush

      script = +"set -a\n. #{Shellwords.escape(file.path)}\n"
      script << "[ -f #{Shellwords.escape(config_path)} ] && . #{Shellwords.escape(config_path)}\n"
      OVERRIDABLE_KEYS.each { |key| script << %(echo "#{key}=${#{key}}"\n) }

      output = `timeout 3 bash -c #{Shellwords.escape(script)} 2>/dev/null`
      next record if output.strip.empty?

      effective_values = record.dup
      output.each_line(chomp: true) do |line|
        key, _, value = line.partition("=")
        effective_values[key] = value if OVERRIDABLE_KEYS.include?(key) && !value.empty?
      end
      effective_values
    end
  rescue StandardError
    record || {}
  end
end
