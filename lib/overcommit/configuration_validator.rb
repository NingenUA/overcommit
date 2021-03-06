module Overcommit
  # Validates and normalizes a configuration.
  class ConfigurationValidator
    # Validates hash for any invalid options, normalizing where possible.
    #
    # @param hash [Hash] hash representation of YAML config
    # @param options[Hash]
    # @option default [Boolean] whether hash represents the default built-in config
    # @option logger [Overcommit::Logger] logger to output warnings to
    # @return [Hash] validated hash (potentially modified)
    def validate(hash, options)
      @options = options.dup
      @log = options[:logger]

      hash = convert_nils_to_empty_hashes(hash)
      ensure_hook_type_sections_exist(hash)
      check_for_missing_enabled_option(hash) unless @options[:default]

      hash
    end

    private

    # Ensures that keys for all supported hook types exist (PreCommit,
    # CommitMsg, etc.)
    def ensure_hook_type_sections_exist(hash)
      Overcommit::Utils.supported_hook_type_classes.each do |hook_type|
        hash[hook_type] ||= {}
        hash[hook_type]['ALL'] ||= {}
      end
    end

    # Normalizes `nil` values to empty hashes.
    #
    # This is useful for when we want to merge two configuration hashes
    # together, since it's easier to merge two hashes than to have to check if
    # one of the values is nil.
    def convert_nils_to_empty_hashes(hash)
      hash.each_with_object({}) do |(key, value), h|
        h[key] =
          case value
          when nil  then {}
          when Hash then convert_nils_to_empty_hashes(value)
          else
            value
          end
      end
    end

    # Prints a warning if there are any hooks listed in the configuration
    # without `enabled` explicitly set.
    def check_for_missing_enabled_option(hash)
      return unless @log

      any_warnings = false

      Overcommit::Utils.supported_hook_type_classes.each do |hook_type|
        hash.fetch(hook_type, {}).each do |hook_name, hook_config|
          next if hook_name == 'ALL'

          if hook_config['enabled'].nil?
            @log.warning "#{hook_type}::#{hook_name} hook does not explicitly " \
                         'set `enabled` option in .overcommit.yml'
            any_warnings = true
          end
        end
      end

      @log.newline if any_warnings
    end
  end
end
