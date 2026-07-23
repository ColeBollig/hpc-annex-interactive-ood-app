# Best-effort reader/typer for the pilot's own effective HTCondor config
# values (currently just STARTD_NOCLAIM_SHUTDOWN), resolved from plain-text
# config fragments already on disk -- no live pilot process, no executing
# any HTCondor binary, and no HTCondor macro expansion/conditionals/built-in
# functions. See this app's README.md Session Card Info section for why.
#
# NOT `require`d directly by info.html.erb -- `__dir__` doesn't reliably
# resolve inside info.html.erb's own OOD rendering path (confirmed by a real
# production LoadError; see git history). Instead, submit.yml.erb copies
# this file into staged_root (where __dir__ IS reliable), and info.html.erb
# `load`s it back from there by an explicit staged_root-based path instead.
module AnnexPilotConfig
  module_function

  # Sources are read in the same order the pilot's own config.d loads them
  # -- last definition of `key` wins, same rule HTCondor's own config parser
  # uses:
  #
  # 1. 00-annex-pilot-base       -- shipped in the tarball; hardcodes the
  #    built-in default, present as soon as before.sh.erb extracts it.
  # 2. 10-annex-pilot-instance   -- written by annex-setup.sh into
  #    staged_root during before.sh.erb; already reflects any
  #    ~/.condor/annex_config shell override, since annex-setup.sh sources
  #    that file before writing this one.
  # 3. ~/.condor/annex_pilot_config -- the user's own optional file, later
  #    copied verbatim into the pilot's config.d (highest precedence) by
  #    annex-job-setup.sh. Read directly here instead of waiting for that
  #    copy to happen on the compute node -- it's the exact same content.
  def config_sources(staged_root)
    [
      File.join(staged_root.to_s, "00-annex-pilot-base"),
      File.join(staged_root.to_s, "10-annex-pilot-instance"),
      File.expand_path("~/.condor/annex_pilot_config"),
    ]
  end

  # Only understands plain "KEY = VALUE" lines -- not macro expansion,
  # conditionals, or any of HTCondor's built-in functions. Returns the last
  # matching value across all sources (in order), or nil if none define it.
  def value(staged_root, key)
    result = nil
    config_sources(staged_root).each do |path|
      next unless File.exist?(path)
      File.foreach(path) do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        k, sep, v = line.partition("=")
        next if sep.empty? || k.strip.upcase != key.upcase
        result = v.strip
      end
    end
    result
  end

  # Best-effort typing only -- HTCondor supports macro expansion,
  # conditionals, and built-in functions ($(...), ifThenElse, etc.) that this
  # doesn't replicate, so anything that isn't a plain int/float/bool literal
  # comes back as the raw string. Integer is tried before Float since
  # Float("5") would also succeed.
  def coerce(raw)
    return nil if raw.nil?

    begin
      return Integer(raw)
    rescue ArgumentError, TypeError
    end

    begin
      return Float(raw)
    rescue ArgumentError, TypeError
    end

    return true if raw.match?(/\Atrue\z/i)
    return false if raw.match?(/\Afalse\z/i)

    raw
  end

  def humanize_seconds(seconds)
    parts = []
    remaining = seconds
    [[3600, "hour"], [60, "minute"], [1, "second"]].each do |unit_seconds, name|
      count, remaining = remaining.divmod(unit_seconds)
      parts << "#{count} #{name}#{"s" unless count == 1}" if count > 0
    end
    parts.empty? ? "0 seconds" : parts.join(" ")
  end

  # Not a constant: this file is `load`ed fresh on every card render (see
  # top-of-file comment), and reassigning a module constant on every load
  # would spam "already initialized constant" warnings.
  def static_shutdown_warning
    "Pilot may exit early after a set amount of time without any job pressure. See configured <code>STARTD_NOCLAIM_SHUTDOWN</code> value."
  end

  # Returns the session-card warning HTML: a specific, human-readable
  # shutdown time if STARTD_NOCLAIM_SHUTDOWN resolves to a plain integer,
  # otherwise the generic static fallback (e.g. it's unset, or overridden to
  # an expression this doesn't evaluate).
  def shutdown_warning(staged_root)
    resolved = coerce(value(staged_root, "STARTD_NOCLAIM_SHUTDOWN"))
    return static_shutdown_warning unless resolved.is_a?(Integer)

    "This job's execute point may shut down after #{humanize_seconds(resolved)} without any job pressure."
  rescue StandardError
    static_shutdown_warning
  end
end
