# Shared admin-configuration resolution for form.yml.erb and submit.yml.erb.
# Required by both via `require File.join(__dir__, "lib", "annex_defaults.rb")`
# so the parsing/validation logic and built-in fallbacks live in exactly one
# place instead of being copy-pasted across the two independently-rendered
# ERB templates.
module AnnexDefaults
  # name: the HTC_ANNEX_{MIN,MAX,DEFAULT}_<name> env var suffix
  # floor: the resource's hard lower bound (0 for GPUs, since "0 GPUs" is the
  #   documented way to request a CPU-only node; 1 for cores/memory, since a
  #   job can't sensibly request zero of either).
  RESOURCES = {
    num_cores: { env: "NUM_CORES", builtin_min: 1, builtin_max: 128, builtin_default: 1, floor: 1 },
    memory_gb: { env: "MEMORY_GB", builtin_min: 1, builtin_max: 512, builtin_default: 4, floor: 1 },
    num_gpus:  { env: "NUM_GPUS",  builtin_min: 0, builtin_max: 8,   builtin_default: 0, floor: 0 },
  }.freeze

  # user_email/bc_account are interpolated into double-quoted YAML strings in
  # submit.yml.erb, so they're restricted to safe character sets before use —
  # an unescaped `"` or newline in a raw form value would otherwise corrupt
  # the generated YAML (at best breaking the user's own submission, at worst
  # letting a crafted value inject extra `native:` entries beyond what the
  # form allows).
  ACCOUNT_RE = /\A[\w.-]+\z/
  EMAIL_RE = /\A[\w+\-.]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+\z/

  module_function

  def parse_int(name, fallback)
    raw = ENV[name].to_s.strip
    raw.match?(/\A\d+\z/) ? raw.to_i : fallback
  end

  # Resolves one resource's {min, max, default}, each independently
  # overridable via HTC_ANNEX_MIN_<env>/HTC_ANNEX_MAX_<env>/HTC_ANNEX_DEFAULT_<env>.
  #
  # An inconsistent admin-supplied min/max (below the resource's floor, or
  # max < min) can't be sensibly repaired -- both bounds fall back to the
  # built-in range entirely rather than guessing which one the admin meant.
  # A default outside the (possibly admin-supplied) [min, max] is clamped
  # into range rather than discarded, since the min/max themselves are still
  # trustworthy in that case.
  def resolve_range(name)
    cfg = RESOURCES.fetch(name)

    min = parse_int("HTC_ANNEX_MIN_#{cfg[:env]}", cfg[:builtin_min])
    max = parse_int("HTC_ANNEX_MAX_#{cfg[:env]}", cfg[:builtin_max])
    min, max = cfg[:builtin_min], cfg[:builtin_max] if min < cfg[:floor] || max < min

    default = parse_int("HTC_ANNEX_DEFAULT_#{cfg[:env]}", cfg[:builtin_default]).clamp(min, max)

    { min: min, max: max, default: default }
  end

  def resolve_all
    RESOURCES.each_key.to_h { |name| [name, resolve_range(name)] }
  end

  # Whether to offer email notifications. An admin can force this on/off
  # per-install via HTC_ANNEX_EMAIL_ENABLED in this app's `env` file
  # (/etc/ood/config/apps/<app_token>/env) when autodetection isn't reliable
  # (e.g. MailProg is configured but the mail relay is actually broken).
  # Falls back to autodetecting via `scontrol show config` (any user can run
  # this; no admin rights required) when the override isn't set. Wrapped in
  # `timeout` so an unresponsive slurmctld can't hang every user's page load.
  def email_supported?
    case ENV["HTC_ANNEX_EMAIL_ENABLED"].to_s.strip.downcase
    when "1", "true", "yes" then true
    when "0", "false", "no" then false
    else
      mail_prog = `timeout 3 scontrol show config 2>/dev/null`[/^MailProg\s*=\s*(.+)$/, 1].to_s.strip
      !mail_prog.empty? && mail_prog != "(null)"
    end
  end
end
